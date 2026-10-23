import SwiftUI
import SwiftData

/// Trailing inspector for the selected invoice: the paper itself, then what
/// to do with it, then the numbers behind it.
struct InvoiceInspector: View {
    let invoiceID: UUID

    @EnvironmentObject var appState: AppState
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext

    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var showingExchangeRate = false
    @State private var pendingDelete = false
    @State private var previewLanguage: PDFLanguage = .german

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    private var invoice: Invoice? {
        usesSwiftData
            ? sdInvoices.first { $0.id == invoiceID }?.toLegacy()
            : appState.invoices.first { $0.id == invoiceID }
    }
    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }
    private func client(for invoice: Invoice) -> Client? {
        usesSwiftData
            ? sdClients.first { $0.id == invoice.clientId }?.toLegacy()
            : appState.clients.first { $0.id == invoice.clientId }
    }
    private var actions: InvoiceActions {
        InvoiceActions(modelContext: modelContext, appState: appState, sdInvoices: sdInvoices)
    }

    var body: some View {
        if let invoice {
            content(invoice)
        } else {
            ContentUnavailableView("Invoice not found", systemImage: "doc.text")
        }
    }

    private func content(_ invoice: Invoice) -> some View {
        let client = client(for: invoice)
        let profile = profile ?? CompanyProfile()
        let isVatExempt = profile.isVatExempt
        let total = isVatExempt ? invoice.subtotal : invoice.total
        let status: InvoiceStatus = (invoice.status == .sent && invoice.isOverdue) ? .overdue : invoice.status
        let baseCurrency = profile.defaultCurrency

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // The document
                GeometryReader { geo in
                    InvoicePaper(invoice: invoice, client: client, profile: profile, language: previewLanguage, width: min(geo.size.width, 300))
                        .frame(maxWidth: .infinity)
                }
                .aspectRatio(1 / 1.4142, contentMode: .fit)
                .frame(maxWidth: 300)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s)

                // Headline
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(invoice.invoiceNumber)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        StatusBadge(status: status, prominent: true)
                    }
                    MoneyText(total, invoice.currency, font: .title, weight: .semibold)
                    if let client {
                        Button {
                            nav.reveal(clientID: client.id)
                        } label: {
                            Text(client.name)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show client")
                    }
                    if let relative = Dates.relativeDue(invoice.dueDate, status: status) {
                        Text(relative)
                            .font(.callout)
                            .foregroundStyle(status == .overdue ? Color.red : .secondary)
                    } else if status == .paid, let paidAt = invoice.paidAt {
                        Text("Paid on \(Dates.medium.string(from: paidAt))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Actions
                actionsSection(invoice, client: client, profile: profile, status: status, baseCurrency: baseCurrency)

                Divider()

                // Numbers
                VStack(alignment: .leading, spacing: Spacing.m) {
                    DetailRow(label: "Issued", value: Dates.medium.string(from: invoice.issueDate))
                    DetailRow(label: "Due", value: Dates.medium.string(from: invoice.dueDate), valueColor: status == .overdue ? .red : nil)
                    if let sentAt = invoice.sentAt {
                        DetailRow(label: "Sent", value: Dates.medium.string(from: sentAt))
                    }
                    if let paidAt = invoice.paidAt {
                        DetailRow(label: "Paid", value: Dates.medium.string(from: paidAt))
                    }
                    if invoice.currency != baseCurrency, let base = invoice.paidAmountInBaseCurrency {
                        DetailRow(label: "Received", value: Money.string(base, baseCurrency))
                        if let rate = invoice.paidExchangeRate {
                            DetailRow(label: "Rate", value: "1 \(invoice.currency.rawValue) = \(String(format: "%.4f", rate)) \(baseCurrency.rawValue)")
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.m) {
                    ForEach(invoice.lineItems) { item in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.description.nilIfEmpty ?? "Untitled item")
                                Text("\(Money.quantity(item.quantity)) × \(Money.string(item.unitPrice, invoice.currency))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Spacer()
                            MoneyText(item.total, invoice.currency, font: .callout)
                        }
                        .font(.callout)
                    }
                    Divider()
                    DetailRow(label: "Subtotal", value: Money.string(invoice.subtotal, invoice.currency))
                    if isVatExempt {
                        DetailRow(label: "VAT", value: "Exempt (§19 UStG)")
                    } else {
                        ForEach(invoice.taxBreakdown, id: \.rate) { b in
                            DetailRow(label: "VAT \(Int(b.rate)) %", value: Money.string(b.amount, invoice.currency))
                        }
                    }
                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        MoneyText(total, invoice.currency, weight: .semibold)
                    }
                }

                if !invoice.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Notes").font(.callout).foregroundStyle(.secondary)
                        Text(invoice.notes).font(.callout).textSelection(.enabled)
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .confirmationDialog("Delete \(invoice.invoiceNumber)?", isPresented: $pendingDelete, titleVisibility: .visible) {
            Button("Delete invoice", role: .destructive) {
                actions.delete(invoice)
                nav.selectedInvoiceID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the invoice. Exported PDFs are not affected.")
        }
        .sheet(isPresented: $showingExchangeRate) {
            ExchangeRateDialog(invoice: invoice, baseCurrency: baseCurrency, isVatExempt: isVatExempt) { rate, baseAmount in
                actions.markPaid(invoice, exchangeRate: rate, amountInBaseCurrency: baseAmount)
            }
        }
    }

    @ViewBuilder
    private func actionsSection(_ invoice: Invoice, client: Client?, profile: CompanyProfile, status: InvoiceStatus, baseCurrency: Currency) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Primary: the next step in the invoice's life.
            switch status {
            case .draft:
                HStack(spacing: Spacing.s) {
                    Button("Mark as sent", systemImage: "paperplane") { actions.markSent(invoice) }
                        .buttonStyle(.glassProminent)
                    Button("Edit", systemImage: "pencil") { nav.sheet = .editInvoice(invoice) }
                        .buttonStyle(.glass)
                }
            case .sent, .overdue:
                Button("Mark as paid", systemImage: "checkmark.circle") {
                    if invoice.currency == baseCurrency {
                        actions.markPaid(invoice)
                    } else {
                        showingExchangeRate = true
                    }
                }
                .buttonStyle(.glassProminent)
            case .paid, .cancelled:
                EmptyView()
            }

            HStack(spacing: Spacing.s) {
                Menu {
                    Button("Deutsch") { actions.exportPDF(invoice, client: client, profile: profile, language: .german) }
                    Button("English") { actions.exportPDF(invoice, client: client, profile: profile, language: .english) }
                } label: {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.glass)
                .disabled(client == nil)
                .help(client == nil ? "This invoice has no client" : "Save a PDF")

                Picker("Preview language", selection: $previewLanguage) {
                    Text("DE").tag(PDFLanguage.german)
                    Text("EN").tag(PDFLanguage.english)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 90)
                .help("Preview language")

                Spacer()

                Menu {
                    if status == .sent || status == .overdue {
                        Button("Back to draft", systemImage: "arrow.uturn.backward") { actions.revertToDraft(invoice) }
                    }
                    if status != .paid && status != .cancelled {
                        Button("Cancel invoice", systemImage: "xmark.circle") { actions.cancel(invoice) }
                    }
                    Divider()
                    Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .buttonStyle(.glass)
                .help("More actions")
            }
        }
    }
}
