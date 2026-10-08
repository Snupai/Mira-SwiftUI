import SwiftUI
import SwiftData

struct InvoiceEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    @Query private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdTemplates: [SDInvoiceTemplate]
    @Query private var sdProfiles: [SDCompanyProfile]
    @State private var invoice: Invoice
    @State private var selectedClientId: UUID?
    @State private var showingClientPicker = false
    @State private var showingSaveTemplate = false
    @State private var templateName = ""
    @State private var selectedTemplateName = "No template"
    @State private var initialized = false
    @State private var generatedSequence: Int?
    @State private var generatedNumber = ""
    @State private var saveError: String?
    @State private var showingSaveError = false
    let isEditing: Bool

    init(invoice: Invoice?) {
        _invoice = State(initialValue: invoice ?? Invoice(clientId: UUID()))
        _selectedClientId = State(initialValue: invoice?.clientId)
        isEditing = invoice != nil
    }

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }
    private var allTemplates: [InvoiceTemplate] {
        usesSwiftData ? sdTemplates.map { $0.toLegacy() } : appState.templates
    }
    private var selectedClient: Client? {
        guard let id = selectedClientId else { return nil }
        return usesSwiftData ? sdClients.first { $0.id == id }?.toLegacy() : appState.clients.first { $0.id == id }
    }
    private var isVatExempt: Bool {
        usesSwiftData ? sdProfiles.first?.isVatExempt ?? false : appState.companyProfile?.isVatExempt ?? false
    }
    private var defaultCurrency: Currency {
        usesSwiftData ? sdProfiles.first?.defaultCurrency ?? .eur : appState.companyProfile?.defaultCurrency ?? .eur
    }
    private var defaultVatRate: Double {
        if isVatExempt { return 0 }
        return usesSwiftData ? sdProfiles.first?.defaultVatRate ?? 19 : appState.companyProfile?.defaultVatRate ?? 19
    }
    private var defaultPaymentTerms: Int {
        usesSwiftData ? sdProfiles.first?.defaultPaymentTermsDays ?? 14 : appState.companyProfile?.defaultPaymentTermsDays ?? 14
    }
    private var existingNumbers: [String] {
        usesSwiftData ? sdInvoices.filter { $0.id != invoice.id }.map(\.invoiceNumber)
            : appState.invoices.filter { $0.id != invoice.id }.map(\.invoiceNumber)
    }
    private var validationIssues: [String] {
        InvoiceValidation.issues(for: invoice, hasClient: selectedClient != nil, existingNumbers: existingNumbers)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !isEditing && !allTemplates.isEmpty {
                        Menu {
                            Button("No template") { resetTemplate() }
                            ForEach(allTemplates) { template in
                                Button(template.name) { applyTemplate(template) }
                            }
                        } label: { Label(selectedTemplateName, systemImage: "doc.on.doc") }
                    }
                    FormSection(title: "Client", colors: colors) {
                        Button { showingClientPicker = true } label: {
                            HStack {
                                Text(selectedClient?.name ?? "Select a client…")
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .padding(12)
                            .foregroundStyle(colors.text)
                            .background(colors.surface1, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Client: \(selectedClient?.name ?? "None selected")")
                    }
                    FormSection(title: "Details", colors: colors) {
                        VStack(spacing: 16) {
                            FormField(label: "Invoice Number", text: $invoice.invoiceNumber, required: true, colors: colors)
                            HStack(spacing: 20) {
                                Picker("Currency", selection: $invoice.currency) {
                                    ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                                Spacer()
                                DatePicker("Issued", selection: $invoice.issueDate, displayedComponents: .date)
                                DatePicker("Due", selection: $invoice.dueDate, displayedComponents: .date)
                            }
                            .foregroundStyle(colors.text)
                        }
                    }
                    FormSection(title: "Line Items", colors: colors) {
                        VStack(alignment: .leading, spacing: 12) {
                            if invoice.lineItems.isEmpty {
                                Text("Add the services or products you’re invoicing.")
                                    .foregroundStyle(colors.subtext)
                            } else {
                                HStack {
                                    Text("Description").frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Qty").frame(width: 70)
                                    Text("Unit Price").frame(width: 110)
                                    Text("Total").frame(width: 90, alignment: .trailing)
                                    Spacer().frame(width: 24)
                                }
                                .font(.caption).foregroundStyle(colors.subtext)
                                ForEach($invoice.lineItems) { $item in
                                    LineItemEditor(item: $item, currency: invoice.currency) {
                                        invoice.lineItems.removeAll { $0.id == item.id }
                                    }
                                }
                            }
                            Button("Add item", systemImage: "plus", action: addLineItem)
                                .help("Add a line item")
                        }
                    }
                    totalsSection
                    FormSection(title: "Notes", colors: colors) {
                        TextEditor(text: $invoice.notes)
                            .font(.body).foregroundStyle(colors.text)
                            .scrollContentBackground(.hidden)
                            .padding(10).frame(height: 100)
                            .background(colors.surface1, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Invoice notes")
                    }
                    if !validationIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To save this invoice:").font(.subheadline.weight(.medium))
                            ForEach(validationIssues, id: \.self) { Text("• " + $0) }
                        }
                        .font(.caption).foregroundStyle(colors.subtext)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(24)
            }
            .background(colors.base)
            .navigationTitle(isEditing ? "Edit Invoice" : "New Invoice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu { Button("Save as Template") { showingSaveTemplate = true } }
                    label: { Label("More actions", systemImage: "ellipsis.circle") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveInvoice).miraPrimaryAction()
                        .disabled(!validationIssues.isEmpty)
                }
            }
            .alert("Save as Template", isPresented: $showingSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Cancel", role: .cancel) { templateName = "" }
                Button("Save", action: saveAsTemplate)
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .alert("Could not save", isPresented: $showingSaveError) {
                Button("Keep Editing", role: .cancel) { }
            } message: { Text(saveError ?? "Please try again.") }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClientId: $selectedClientId)
                    .environmentObject(appState).environment(\.themeColors, colors)
            }
            .onAppear { initializeInvoice() }
            .onChange(of: selectedClientId) { _, _ in
                guard !isEditing, let client = selectedClient else { return }
                invoice.currency = client.defaultCurrency ?? defaultCurrency
                invoice.dueDate = Calendar.current.date(byAdding: .day, value: client.defaultPaymentTermsDays ?? defaultPaymentTerms, to: invoice.issueDate) ?? invoice.issueDate
            }
        }
        .frame(width: 740, height: 720)
    }

    private var totalsSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Subtotal  " + MiraFormat.currency(invoice.subtotal, invoice.currency))
            if isVatExempt {
                Text("VAT exempt (§19 UStG)").font(.caption)
            } else {
                ForEach(invoice.taxBreakdown, id: \.rate) { tax in
                    Text("VAT \(tax.rate.formatted())%  " + MiraFormat.currency(tax.amount, invoice.currency))
                }
            }
            Divider().frame(width: 220)
            Text("Total  " + MiraFormat.currency(isVatExempt ? invoice.taxableAmount : invoice.total, invoice.currency))
                .font(.title3.weight(.semibold))
        }
        .foregroundStyle(colors.text)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func initializeInvoice() {
        guard !initialized else { return }
        initialized = true
        guard !isEditing else { return }
        invoice.currency = defaultCurrency
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: defaultPaymentTerms, to: invoice.issueDate) ?? invoice.issueDate
        let prefix = usesSwiftData ? sdProfiles.first?.invoiceNumberPrefix ?? "INV-" : appState.companyProfile?.invoiceNumberPrefix ?? "INV-"
        var sequence = usesSwiftData ? sdProfiles.first?.nextInvoiceNumber ?? 1 : appState.companyProfile?.nextInvoiceNumber ?? 1
        let year = Calendar.current.component(.year, from: invoice.issueDate)
        func number(_ value: Int) -> String { "\(prefix)\(year)-\(String(format: "%04d", value))" }
        while existingNumbers.contains(where: { $0.caseInsensitiveCompare(number(sequence)) == .orderedSame }) { sequence += 1 }
        generatedSequence = sequence
        generatedNumber = number(sequence)
        invoice.invoiceNumber = generatedNumber
    }

    private func addLineItem() {
        invoice.lineItems.append(LineItem(vatRate: isVatExempt ? 0 : selectedClient?.defaultVatRate ?? defaultVatRate))
    }
    private func applyTemplate(_ template: InvoiceTemplate) {
        invoice.lineItems = template.lineItems.map { item in var copy = item; copy.id = UUID(); if isVatExempt { copy.vatRate = 0 }; return copy }
        invoice.notes = template.notes
        invoice.paymentNotes = template.paymentNotes
        selectedClientId = template.defaultClientId
        selectedTemplateName = template.name
    }
    private func resetTemplate() {
        invoice.lineItems = []
        invoice.notes = ""
        invoice.paymentNotes = ""
        selectedTemplateName = "No template"
    }
    private func report(_ error: Error) {
        saveError = error.localizedDescription
        showingSaveError = true
    }
    private func saveAsTemplate() {
        var template = InvoiceTemplate()
        template.name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.name.isEmpty else { return }
        template.lineItems = invoice.lineItems
        template.notes = invoice.notes
        template.paymentNotes = invoice.paymentNotes
        template.defaultClientId = selectedClientId
        do {
            if usesSwiftData {
                let stored = SDInvoiceTemplate(from: template, defaultClient: sdClients.first { $0.id == selectedClientId })
                stored.defaultClientId = selectedClientId
                modelContext.insert(stored)
                do { try modelContext.save() } catch { modelContext.rollback(); throw error }
            } else {
                let templates = appState.templates + [template]
                try appState.persistTemplates(templates)
                appState.templates = templates
            }
            templateName = ""
        } catch { report(error) }
    }
    private func saveInvoice() {
        guard validationIssues.isEmpty, let clientId = selectedClientId else { return }
        invoice.clientId = clientId
        invoice.invoiceNumber = invoice.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        invoice.updatedAt = Date()
        do {
            if usesSwiftData {
                // Recheck against the store at save time, including edits from another window.
                let records = try modelContext.fetch(FetchDescriptor<SDInvoice>())
                let issues = InvoiceValidation.issues(for: invoice, hasClient: true,
                    existingNumbers: records.filter { $0.id != invoice.id }.map(\.invoiceNumber))
                guard issues.isEmpty else { saveError = issues.joined(separator: "\n"); showingSaveError = true; return }
                guard let client = sdClients.first(where: { $0.id == clientId }) else { throw MiraPersistenceError.missingClient }
                if isEditing {
                    guard let existing = records.first(where: { $0.id == invoice.id }), existing.status == .draft else { throw MiraPersistenceError.missingRecord }
                    existing.invoiceNumber = invoice.invoiceNumber
                    existing.issueDate = invoice.issueDate
                    existing.dueDate = invoice.dueDate
                    existing.lineItems = invoice.lineItems.map { SDLineItem(from: $0) }
                    existing.currency = invoice.currency
                    existing.notes = invoice.notes
                    existing.paymentNotes = invoice.paymentNotes
                    existing.client = client
                    existing.updatedAt = Date()
                } else {
                    modelContext.insert(SDInvoice(from: invoice, client: client))
                    if invoice.invoiceNumber == generatedNumber, let sequence = generatedSequence, let profile = sdProfiles.first {
                        profile.nextInvoiceNumber = max(profile.nextInvoiceNumber, sequence + 1)
                        profile.updatedAt = Date()
                    }
                }
                do { try modelContext.save() } catch { modelContext.rollback(); throw error }
            } else {
                var invoices = appState.invoices
                if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
                    // A retry after a legacy profile write failure must not insert the invoice twice.
                    invoices[index] = invoice
                } else {
                    guard !isEditing else { throw MiraPersistenceError.missingRecord }
                    invoices.append(invoice)
                }
                try appState.persistInvoices(invoices)
                appState.invoices = invoices
                if !isEditing, invoice.invoiceNumber == generatedNumber, let sequence = generatedSequence, var profile = appState.companyProfile {
                    profile.nextInvoiceNumber = max(profile.nextInvoiceNumber, sequence + 1)
                    try appState.persistCompanyProfile(profile)
                    appState.companyProfile = profile
                }
            }
            dismiss()
        } catch { report(error) }
    }
}

struct LineItemEditor: View {
    @Environment(\.themeColors) private var colors
    @Binding var item: LineItem
    let currency: Currency
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Description", text: $item.description)
                .miraInput(colors: colors).accessibilityLabel("Item description")
            TextField("Qty", value: $item.quantity, format: .number)
                .miraInput(colors: colors).frame(width: 70).accessibilityLabel("Item quantity")
            TextField("Price", value: $item.unitPrice, format: .number.precision(.fractionLength(0...2)))
                .miraInput(colors: colors).frame(width: 110).accessibilityLabel("Unit price in \(currency.rawValue)")
            Text(MiraFormat.currency(item.total, currency))
                .monospacedDigit().frame(width: 90, alignment: .trailing)
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.plain).frame(width: 24)
                .accessibilityLabel("Remove line item").help("Remove line item")
        }
        .font(.body).foregroundStyle(colors.text)
    }
}

struct ClientPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDClient.name) private var sdClients: [SDClient]
    @Binding var selectedClientId: UUID?
    @State private var showingNewClient = false
    @State private var newClient = Client()
    @State private var searchText = ""
    
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    private var allClients: [Client] {
        if usesSwiftData {
            return sdClients.map { $0.toLegacy() }
        }
        return appState.clients
    }
    
    var body: some View {
        let clients = allClients
        let filtered = clients.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.email.localizedCaseInsensitiveContains(searchText) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if clients.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 32))
                                .foregroundColor(colors.subtext)
                            Text("No clients yet")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(colors.text)
                            Text("Create a new client using the button above")
                                .font(.system(size: 13))
                                .foregroundColor(colors.subtext)
                        }
                        .padding(.top, 60)
                    } else if filtered.isEmpty {
                        Text("No matching clients").foregroundStyle(colors.subtext)
                        Button("Clear search") { searchText = "" }
                    } else {
                        ForEach(filtered) { client in
                            Button(action: {
                                selectedClientId = client.id
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(client.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(colors.text)
                                        if !client.email.isEmpty {
                                            Text(client.email)
                                                .font(.system(size: 13))
                                                .foregroundColor(colors.subtext)
                                        }
                                    }
                                    Spacer()
                                    if selectedClientId == client.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(colors.accent)
                                    }
                                }
                                .padding(14)
                                .background(selectedClientId == client.id ? colors.accent.opacity(0.1) : colors.surface0)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Select Client")
            .searchable(text: $searchText, prompt: "Search clients")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Client", systemImage: "plus") {
                        newClient = Client()
                        showingNewClient = true
                    }
                    .miraPrimaryAction()
                }
            }
        }
        .frame(width: 400, height: 350)
        .sheet(isPresented: $showingNewClient) {
            QuickClientEditorView(client: $newClient) { savedClient in
                if usesSwiftData {
                    let stored = SDClient(from: savedClient)
                    modelContext.insert(stored)
                    do { try modelContext.save() }
                    catch { modelContext.rollback(); throw error }
                } else {
                    let clients = appState.clients + [savedClient]
                    try appState.persistClients(clients)
                    appState.clients = clients
                }
                selectedClientId = savedClient.id
                showingNewClient = false
                dismiss()
            }
            .environmentObject(appState)
            .environment(\.themeColors, colors)
        }
    }
}

// Quick client editor for creating new clients from invoice flow
struct QuickClientEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    @Binding var client: Client
    var onSave: (Client) throws -> Void
    @State private var saveError: String?
    @State private var showingSaveError = false
    
    var canSave: Bool { !client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.subtext)
                        
                        VStack(spacing: 12) {
                            QuickField(label: "Company / Name *", text: $client.name, colors: colors)
                            QuickField(label: "Contact Person", text: $client.contactPerson, colors: colors)
                            QuickField(label: "Email", text: $client.email, colors: colors)
                            QuickField(label: "Phone", text: $client.phone, colors: colors)
                        }
                    }
                    
                    // Address
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Address")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.subtext)
                        
                        VStack(spacing: 12) {
                            QuickField(label: "Street", text: $client.street, colors: colors)
                            HStack(spacing: 12) {
                                QuickField(label: "Postal Code", text: $client.postalCode, colors: colors)
                                    .frame(width: 100)
                                QuickField(label: "City", text: $client.city, colors: colors)
                            }
                            QuickField(label: "Country", text: $client.country, colors: colors)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        client.updatedAt = Date()
                        do {
                            client.name = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            try onSave(client)
                        } catch {
                            saveError = error.localizedDescription
                            showingSaveError = true
                        }
                    }
                    .miraPrimaryAction()
                    .disabled(!canSave)
                }
            }
        }
        .frame(width: 440, height: 540)
        .alert("Client could not be saved", isPresented: $showingSaveError) {
            Button("Keep Editing", role: .cancel) { }
        } message: { Text(saveError ?? "Please try again.") }
    }
}

struct QuickField: View {
    let label: String
    @Binding var text: String
    let colors: ThemeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(colors.subtext)
            TextField(label, text: $text)
                .accessibilityLabel(label)
                .miraInput(colors: colors)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct InvoiceEditorView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceEditorView(invoice: nil).environmentObject(AppState())
    }
}
