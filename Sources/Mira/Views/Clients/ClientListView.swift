import SwiftUI
import SwiftData
import os

/// Clients as a searchable list with the selected client in a trailing
/// inspector. Each row shows what matters at a glance: who they are and
/// what they still owe.
struct ClientListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SDClient.name) private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var searchText = ""
    @State private var showInspector = true
    @State private var pendingDelete: Client?

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }
    private var isVatExempt: Bool { profile?.isVatExempt ?? false }
    private var baseCurrency: Currency { profile?.defaultCurrency ?? .eur }

    private var allClients: [Client] {
        (usesSwiftData ? sdClients.map { $0.toLegacy() } : appState.clients)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    private var allInvoices: [Invoice] {
        usesSwiftData ? sdInvoices.map { $0.toLegacy() } : appState.invoices
    }

    private var filteredClients: [Client] {
        guard !searchText.isEmpty else { return allClients }
        return allClients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.contactPerson.localizedCaseInsensitiveContains(searchText)
                || $0.email.localizedCaseInsensitiveContains(searchText)
                || $0.city.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Per-client invoice summary used by the rows.
    private struct Summary {
        var count = 0
        var outstanding: Double = 0
        var outstandingCurrency: Currency = .eur
        var hasOverdue = false
    }

    private var summaries: [UUID: Summary] {
        var result: [UUID: Summary] = [:]
        for invoice in allInvoices {
            var s = result[invoice.clientId, default: Summary(outstandingCurrency: baseCurrency)]
            s.count += 1
            if invoice.status == .sent || invoice.status == .overdue {
                s.outstanding += isVatExempt ? invoice.subtotal : invoice.total
                s.outstandingCurrency = invoice.currency
                if invoice.status == .overdue || invoice.isOverdue { s.hasOverdue = true }
            }
            result[invoice.clientId] = s
        }
        return result
    }

    // MARK: Body

    var body: some View {
        @Bindable var nav = nav
        Group {
            if filteredClients.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Clients")
        .navigationSubtitle("\(allClients.count) \(allClients.count == 1 ? "client" : "clients")")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search clients")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New client", systemImage: "plus") {
                    nav.sheet = .newClient
                }
                .help("New client (⌘⇧N)")
            }
            ToolbarItem(placement: .automatic) {
                Button("Inspector", systemImage: "sidebar.trailing") {
                    withAnimation { showInspector.toggle() }
                }
                .help("Show or hide the inspector")
            }
        }
        .inspector(isPresented: $showInspector) {
            Group {
                if let id = nav.selectedClientID, allClients.contains(where: { $0.id == id }) {
                    ClientInspector(clientID: id)
                } else {
                    ContentUnavailableView {
                        Label("No client selected", systemImage: "person")
                    } description: {
                        Text("Select a client to see their details and invoices.")
                    }
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 440)
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "client")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete client", role: .destructive) {
                if let client = pendingDelete { delete(client) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Their invoices are kept but lose the link to this client.")
        }
        .onChange(of: nav.selectedClientID) { _, id in
            if id != nil && !showInspector { withAnimation { showInspector = true } }
        }
        .onChange(of: allClients.count) { _, _ in
            if let id = nav.selectedClientID, !allClients.contains(where: { $0.id == id }) {
                nav.selectedClientID = nil
            }
        }
    }

    private var list: some View {
        @Bindable var nav = nav
        let summaries = summaries
        return List(selection: $nav.selectedClientID) {
            ForEach(filteredClients) { client in
                row(client, summary: summaries[client.id] ?? Summary(outstandingCurrency: baseCurrency))
                    .tag(client.id)
                    .contextMenu {
                        Button("New invoice", systemImage: "plus") { nav.sheet = .newInvoice(clientID: client.id) }
                        Button("Edit", systemImage: "pencil") { nav.sheet = .editClient(client) }
                        Divider()
                        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = client }
                    }
            }
        }
        .listStyle(.inset)
    }

    private func row(_ client: Client, summary: Summary) -> some View {
        HStack(spacing: Spacing.m) {
            ClientAvatar(name: client.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let secondary = client.contactPerson.nilIfEmpty ?? client.email.nilIfEmpty {
                    Text(secondary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.count == 0 ? "No invoices" : "\(summary.count) \(summary.count == 1 ? "invoice" : "invoices")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if summary.outstanding > 0 {
                    MoneyText(summary.outstanding, summary.outstandingCurrency, font: .callout, weight: .medium)
                        .foregroundStyle(summary.hasOverdue ? Color.red : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        Group {
            if allClients.isEmpty {
                ContentUnavailableView {
                    Label("No clients yet", systemImage: "person.2")
                } description: {
                    Text("Add the people and companies you invoice. Their details fill in on every invoice automatically.")
                } actions: {
                    Button("Add client") { nav.sheet = .newClient }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    // MARK: Actions

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
        if nav.selectedClientID == client.id { nav.selectedClientID = nil }
    }
}

#Preview {
    ClientListView()
        .environmentObject(AppState())
        .environment(NavigationModel())
}
