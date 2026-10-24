import SwiftUI
import SwiftData
import os
#if os(macOS)
import AppKit
#endif

/// Trailing inspector for the selected client: who they are, what to do
/// next, and the invoices behind the relationship.
struct ClientInspector: View {
    let clientID: UUID

    @EnvironmentObject var appState: AppState
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext

    @Query private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var pendingDelete = false

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    private var client: Client? {
        usesSwiftData
            ? sdClients.first { $0.id == clientID }?.toLegacy()
            : appState.clients.first { $0.id == clientID }
    }
    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }
    private var isVatExempt: Bool { profile?.isVatExempt ?? false }
    private var baseCurrency: Currency { profile?.defaultCurrency ?? .eur }

    private var invoices: [Invoice] {
        (usesSwiftData ? sdInvoices.map { $0.toLegacy() } : appState.invoices)
            .filter { $0.clientId == clientID }
            .sorted { $0.issueDate > $1.issueDate }
    }

    var body: some View {
        if let client {
            content(client)
        } else {
            ContentUnavailableView("Client not found", systemImage: "person")
        }
    }

    private func content(_ client: Client) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header(client)
                actions(client)
                Divider()
                details(client)
                Divider()
                invoicesBlock(client)
                if !client.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Notes").font(.callout).foregroundStyle(.secondary)
                        Text(client.notes).font(.callout).textSelection(.enabled)
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .confirmationDialog("Delete \(client.name)?", isPresented: $pendingDelete, titleVisibility: .visible) {
            Button("Delete client", role: .destructive) { delete(client) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their invoices are kept but lose the link to this client.")
        }
    }

    // MARK: Sections

    private func header(_ client: Client) -> some View {
        HStack(alignment: .center, spacing: Spacing.l) {
            ClientAvatar(name: client.name, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.title3.weight(.semibold))
                    .textSelection(.enabled)
                if !client.contactPerson.isEmpty {
                    Text(client.contactPerson).foregroundStyle(.secondary)
                }
                if !client.email.isEmpty {
                    Text(client.email).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
    }

    private func actions(_ client: Client) -> some View {
        HStack(spacing: Spacing.s) {
            Button("New invoice", systemImage: "plus") {
                nav.sheet = .newInvoice(clientID: client.id)
            }
            .buttonStyle(.glassProminent)

            Button("Edit", systemImage: "pencil") {
                nav.sheet = .editClient(client)
            }
            .buttonStyle(.glass)

            Spacer()

            Menu {
                Button("Email client", systemImage: "envelope") { email(client) }
                    .disabled(client.email.isEmpty)
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = true }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .buttonStyle(.glass)
            .help("More actions")
            .accessibilityLabel("More actions")
        }
    }

    private func details(_ client: Client) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if !client.email.isEmpty { DetailRow(label: "Email", value: client.email) }
            if !client.phone.isEmpty { DetailRow(label: "Phone", value: client.phone) }
            if !client.formattedAddress.isEmpty {
                HStack(alignment: .top) {
                    Text("Address").foregroundStyle(.secondary)
                    Spacer(minLength: Spacing.m)
                    Text(client.formattedAddress)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                .font(.callout)
            }
            if !client.vatId.isEmpty { DetailRow(label: "VAT ID", value: client.vatId) }
            if !client.taxNumber.isEmpty { DetailRow(label: "Tax number", value: client.taxNumber) }
            DetailRow(label: "Language", value: client.language == "en" ? "English" : "Deutsch")
            DetailRow(label: "Payment terms", value: client.defaultPaymentTermsDays.map { "\($0) days" } ?? "Default")
            DetailRow(label: "Currency", value: client.defaultCurrency.map { "\($0.symbol) \($0.rawValue)" } ?? "Default")
        }
    }

    private func invoicesBlock(_ client: Client) -> some View {
        let invoices = invoices
        let year = Calendar.current.component(.year, from: Date())
        let paidThisYear = invoices
            .filter { $0.status == .paid && Calendar.current.component(.year, from: $0.issueDate) == year }
            .reduce(0.0) { sum, inv in
                if let base = inv.paidAmountInBaseCurrency { return sum + base }
                return inv.currency == baseCurrency ? sum + (isVatExempt ? inv.subtotal : inv.total) : sum
            }
        let open = invoices.filter { $0.status == .sent || $0.status == .overdue }
        let outstanding = open.reduce(0.0) { $0 + (isVatExempt ? $1.subtotal : $1.total) }
        let outstandingCurrency = open.first?.currency ?? baseCurrency

        return VStack(alignment: .leading, spacing: Spacing.m) {
            SectionTitle("Invoices")
            DetailRow(label: "Paid this year", value: Money.string(paidThisYear, baseCurrency))
            DetailRow(label: "Outstanding", value: Money.string(outstanding, outstandingCurrency),
                      valueColor: open.contains { $0.effectiveStatus == .overdue } ? .red : nil)

            if invoices.isEmpty {
                Text("No invoices yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(invoices) { invoice in
                        let status = invoice.effectiveStatus
                        Button {
                            nav.reveal(invoiceID: invoice.id)
                        } label: {
                            HStack(spacing: Spacing.s) {
                                StatusBadge(status: status)
                                Text(invoice.invoiceNumber)
                                    .font(.callout)
                                    .monospacedDigit()
                                Spacer()
                                MoneyText(isVatExempt ? invoice.subtotal : invoice.total, invoice.currency, font: .callout)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Show invoice")
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    // MARK: Actions

    private func email(_ client: Client) {
        #if os(macOS)
        guard let url = URL(string: "mailto:\(client.email)") else { return }
        NSWorkspace.shared.open(url)
        #endif
    }

    private func delete(_ client: Client) {
        if usesSwiftData {
            guard let sd = sdClients.first(where: { $0.id == client.id }) else { return }
            modelContext.delete(sd)
            do {
                try modelContext.save()
            } catch {
                Log.data.error("Client delete failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            appState.clients.removeAll { $0.id == client.id }
            appState.saveClients()
        }
        nav.selectedClientID = nil
    }
}
