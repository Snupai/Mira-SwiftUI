import SwiftUI
import SwiftData
import os

/// Create or edit an invoice. The form sits on the left; the paper on the
/// right redraws as you type so there is no gap between "what I entered" and
/// "what the client will receive".
struct InvoiceEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SDClient.name) private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdTemplates: [SDInvoiceTemplate]
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var invoice: Invoice
    @State private var selectedClientID: UUID?
    @State private var showingNewClient = false
    @State private var showingSaveTemplate = false
    @State private var templateName = ""
    @State private var previewLanguage: PDFLanguage = .german
    @State private var didPrepare = false
    @State private var saveError: String?

    let isEditing: Bool

    init(invoice: Invoice?, preselectedClientID: UUID? = nil) {
        if let invoice {
            _invoice = State(initialValue: invoice)
            _selectedClientID = State(initialValue: invoice.clientId)
            isEditing = true
        } else {
            _invoice = State(initialValue: Invoice(clientId: UUID()))
            _selectedClientID = State(initialValue: preselectedClientID)
            isEditing = false
        }
    }

    // MARK: Data

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }
    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }
    private var clients: [Client] {
        (usesSwiftData ? sdClients.map { $0.toLegacy() } : appState.clients).sorted { $0.name < $1.name }
    }
    private var templates: [InvoiceTemplate] {
        usesSwiftData ? sdTemplates.map { $0.toLegacy() } : appState.templates
    }
    private var selectedClient: Client? {
        selectedClientID.flatMap { id in clients.first { $0.id == id } }
    }
    private var isVatExempt: Bool { profile?.isVatExempt ?? false }
    private var hasContent: Bool {
        invoice.lineItems.contains { !$0.description.isEmpty || $0.unitPrice != 0 }
    }
    private var canSave: Bool { selectedClientID != nil && hasContent && !invoice.invoiceNumber.isEmpty }

    private var displayTotal: Double { isVatExempt ? invoice.subtotal : invoice.total }

    // MARK: Body

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                form
                    .frame(minWidth: 520, idealWidth: 560)
                Divider()
                preview
                    .frame(minWidth: 360)
            }
            .navigationTitle(isEditing ? "Edit \(invoice.invoiceNumber)" : "New invoice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Save as template…", systemImage: "doc.on.doc") { showingSaveTemplate = true }
                            .disabled(!hasContent)
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create invoice") { save() }
                        .disabled(!canSave)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .alert("Save as template", isPresented: $showingSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Cancel", role: .cancel) { templateName = "" }
                Button("Save") { saveAsTemplate() }
            } message: {
                Text("Line items and notes are saved. The client is remembered as a default.")
            }
            .alert("Couldn't save invoice", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .sheet(isPresented: $showingNewClient) {
                ClientEditorView(client: nil) { saved in
                    selectedClientID = saved.id
                    applyClientDefaults(saved)
                }
                .environmentObject(appState)
                .themed()
            }
        }
        .frame(minWidth: 960, idealWidth: 1040, minHeight: 620, idealHeight: 700)
        .onAppear(perform: prepare)
    }

    // MARK: Form

    private var form: some View {
        Form {
            if !isEditing && !templates.isEmpty {
                Section {
                    Menu {
                        ForEach(templates) { template in
                            Button(template.name) { apply(template) }
                        }
                    } label: {
                        Label("Start from a template", systemImage: "doc.on.doc")
                    }
                }
            }

            Section("Client") {
                HStack {
                    Picker("Client", selection: $selectedClientID) {
                        Text("Choose a client").tag(UUID?.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(UUID?.some(client.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedClientID) { _, id in
                        if let id, let client = clients.first(where: { $0.id == id }) {
                            applyClientDefaults(client)
                        }
                    }
                    Button("New client…") { showingNewClient = true }
                }
                if let client = selectedClient, !client.formattedAddress.isEmpty {
                    Text(client.formattedAddress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Details") {
                TextField("Invoice number", text: $invoice.invoiceNumber)
                    .monospacedDigit()
                Picker("Currency", selection: $invoice.currency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                    }
                }
                .pickerStyle(.segmented)
                DatePicker("Issue date", selection: $invoice.issueDate, displayedComponents: .date)
                HStack {
                    DatePicker("Due date", selection: $invoice.dueDate, in: invoice.issueDate..., displayedComponents: .date)
                    Menu {
                        ForEach([7, 14, 30, 60], id: \.self) { days in
                            Button("In \(days) days") {
                                invoice.dueDate = Calendar.current.date(byAdding: .day, value: days, to: invoice.issueDate) ?? invoice.dueDate
                            }
                        }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Set due date from payment terms")
                }
            }

            Section {
                lineItemsEditor
            } header: {
                Text("Items")
            } footer: {
                if invoice.lineItems.isEmpty {
                    Text("Add what you did: a description, how much of it, and the price per unit.")
                }
            }

            Section("Totals") {
                LabeledContent("Subtotal") { MoneyText(invoice.subtotal, invoice.currency) }
                if isVatExempt {
                    LabeledContent("VAT") {
                        Text("Exempt (§19 UStG)").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(invoice.taxBreakdown, id: \.rate) { b in
                        LabeledContent("VAT \(Int(b.rate)) %") { MoneyText(b.amount, invoice.currency) }
                    }
                }
                LabeledContent {
                    MoneyText(displayTotal, invoice.currency, font: .title3, weight: .semibold)
                } label: {
                    Text("Total").fontWeight(.semibold)
                }
            }

            Section("Notes") {
                TextField("Shown on the invoice, below the items", text: $invoice.notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .themedGroupedForm()
    }

    private var lineItemsEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if !invoice.lineItems.isEmpty {
                HStack(spacing: Spacing.s) {
                    Text("Description").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Qty").frame(width: 56, alignment: .trailing)
                    Text("Unit price").frame(width: 96, alignment: .trailing)
                    if !isVatExempt { Text("VAT").frame(width: 72, alignment: .leading) }
                    Text("Amount").frame(width: 96, alignment: .trailing)
                    Color.clear.frame(width: 20, height: 1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach($invoice.lineItems) { $item in
                    HStack(spacing: Spacing.s) {
                        TextField("Description", text: $item.description, prompt: Text("What did you do?"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        TextField("Quantity", value: $item.quantity, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 56)
                        TextField("Unit price", value: $item.unitPrice, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 96)
                        if !isVatExempt {
                            Picker("VAT", selection: $item.vatRate) {
                                Text("0 %").tag(0.0)
                                Text("7 %").tag(7.0)
                                Text("19 %").tag(19.0)
                            }
                            .labelsHidden()
                            .frame(width: 72)
                        }
                        MoneyText(item.total, invoice.currency, font: .callout, weight: .medium)
                            .frame(width: 96, alignment: .trailing)
                        Button {
                            withAnimation(.snappy) { invoice.lineItems.removeAll { $0.id == item.id } }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove item")
                        .accessibilityLabel("Remove item")
                    }
                }
            }
            Button("Add item", systemImage: "plus") {
                withAnimation(.snappy) { addLineItem() }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: Preview

    private var preview: some View {
        VStack(spacing: Spacing.l) {
            GeometryReader { geo in
                let width = min(geo.size.width - Spacing.xxl * 2, (geo.size.height - Spacing.xxl * 2) / 1.4142)
                InvoicePaper(invoice: invoice, client: selectedClient, profile: profile ?? CompanyProfile(), language: previewLanguage, width: max(200, width))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Picker("Preview language", selection: $previewLanguage) {
                Text("Deutsch").tag(PDFLanguage.german)
                Text("English").tag(PDFLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .padding(.bottom, Spacing.l)
        }
        .padding(.top, Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.35))
    }

    // MARK: Logic

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true
        guard !isEditing else { return }
        if let profile {
            invoice.currency = profile.defaultCurrency
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: profile.defaultPaymentTermsDays, to: invoice.issueDate) ?? invoice.dueDate
            invoice.invoiceNumber = profile.generateInvoiceNumber()
        }
        if let client = selectedClient { applyClientDefaults(client) }
        if invoice.lineItems.isEmpty { addLineItem() }
    }

    private func applyClientDefaults(_ client: Client) {
        if let currency = client.defaultCurrency { invoice.currency = currency }
        if let days = client.defaultPaymentTermsDays {
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: days, to: invoice.issueDate) ?? invoice.dueDate
        }
    }

    private func addLineItem() {
        let rate = isVatExempt ? 0.0 : (selectedClient?.defaultVatRate ?? profile?.defaultVatRate ?? 19.0)
        invoice.lineItems.append(LineItem(vatRate: rate))
    }

    private func apply(_ template: InvoiceTemplate) {
        invoice.lineItems = template.lineItems
        invoice.notes = template.notes
        invoice.paymentNotes = template.paymentNotes
        if let clientID = template.defaultClientId { selectedClientID = clientID }
    }

    private func saveAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var template = InvoiceTemplate()
        template.name = name
        template.lineItems = invoice.lineItems
        template.notes = invoice.notes
        template.paymentNotes = invoice.paymentNotes
        template.defaultClientId = selectedClientID

        if usesSwiftData {
            let sd = SDInvoiceTemplate(from: template, defaultClient: nil)
            sd.defaultClientId = selectedClientID
            modelContext.insert(sd)
            do { try modelContext.save() } catch {
                Log.data.error("Template save failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            appState.templates.append(template)
            appState.saveTemplates()
        }
        templateName = ""
    }

    private func save() {
        guard let clientID = selectedClientID else { return }
        invoice.clientId = clientID
        invoice.updatedAt = Date()
        invoice.lineItems.removeAll { $0.description.isEmpty && $0.unitPrice == 0 }

        if usesSwiftData {
            let sdClient = sdClients.first { $0.id == clientID }
            if isEditing, let existing = sdInvoices.first(where: { $0.id == invoice.id }) {
                existing.invoiceNumber = invoice.invoiceNumber
                existing.status = invoice.status
                existing.issueDate = invoice.issueDate
                existing.dueDate = invoice.dueDate
                existing.serviceDate = invoice.serviceDate
                existing.serviceDateEnd = invoice.serviceDateEnd
                existing.lineItems = invoice.lineItems.map { SDLineItem(from: $0) }
                existing.currency = invoice.currency
                existing.discountPercent = invoice.discountPercent
                existing.discountFixed = invoice.discountFixed
                existing.paymentReference = invoice.paymentReference
                existing.paymentNotes = invoice.paymentNotes
                existing.notes = invoice.notes
                existing.internalNotes = invoice.internalNotes
                existing.poNumber = invoice.poNumber
                existing.projectCode = invoice.projectCode
                existing.updatedAt = Date()
                existing.client = sdClient
            } else {
                modelContext.insert(SDInvoice(from: invoice, client: sdClient))
                // Only consume the next number once the invoice really exists.
                if let sdProfile = sdProfiles.first, invoice.invoiceNumber == sdProfile.toLegacy().generateInvoiceNumber() {
                    sdProfile.nextInvoiceNumber += 1
                }
            }
            do {
                try modelContext.save()
            } catch {
                Log.data.error("Invoice save failed: \(error.localizedDescription, privacy: .public)")
                saveError = error.localizedDescription
                return
            }
        } else {
            if isEditing, let index = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                appState.invoices[index] = invoice
            } else {
                appState.invoices.append(invoice)
                if var profile = appState.companyProfile, invoice.invoiceNumber == profile.generateInvoiceNumber() {
                    profile.nextInvoiceNumber += 1
                    appState.companyProfile = profile
                    appState.saveCompanyProfile()
                }
            }
            appState.saveInvoices()
        }
        dismiss()
    }
}

#Preview {
    InvoiceEditorView(invoice: nil).environmentObject(AppState())
}
