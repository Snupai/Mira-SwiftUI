import SwiftUI

struct InvoiceEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    
    @State private var invoice: Invoice
    @State private var selectedClientId: UUID?
    @State private var showingClientPicker = false
    @State private var showingTemplatePicker = false
    @State private var showingSaveTemplate = false
    @State private var templateName = ""
    
    let isEditing: Bool
    
    init(invoice: Invoice?) {
        if let invoice = invoice {
            _invoice = State(initialValue: invoice)
            _selectedClientId = State(initialValue: invoice.clientId)
            isEditing = true
        } else {
            _invoice = State(initialValue: Invoice(clientId: UUID()))
            _selectedClientId = State(initialValue: nil)
            isEditing = false
        }
    }
    
    var selectedClient: Client? {
        guard let id = selectedClientId else { return nil }
        return appState.clients.first { $0.id == id }
    }
    
    var canSave: Bool { selectedClientId != nil && !invoice.lineItems.isEmpty }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Template picker (for new invoices only)
                    if !isEditing && !appState.templates.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Template")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Menu {
                                Button("No template") {
                                    // Reset to blank
                                }
                                Divider()
                                ForEach(appState.templates) { template in
                                    Button(template.name) {
                                        applyTemplate(template)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Select template...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    // Client
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingClientPicker = true }) {
                            HStack {
                                if let client = selectedClient {
                                    Text(client.name)
                                        .font(.system(size: 15))
                                } else {
                                    Text("Select client...")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Invoice Number")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                TextField("INV-2024-0001", text: $invoice.invoiceNumber)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Currency")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $invoice.currency) {
                                    ForEach(Currency.allCases, id: \.self) { currency in
                                        Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .padding(6)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Issue Date")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $invoice.issueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Due Date")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $invoice.dueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                    }
                    
                    // Line Items
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Line Items")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: addLineItem) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(spacing: 8) {
                            ForEach($invoice.lineItems) { $item in
                                LineItemEditor(item: $item, currency: invoice.currency, onDelete: {
                                    invoice.lineItems.removeAll { $0.id == item.id }
                                })
                            }
                        }
                        
                        if invoice.lineItems.isEmpty {
                            Text("No items. Click + to add.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        }
                    }
                    
                    // Totals
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                let isVatExempt = appState.companyProfile?.isVatExempt ?? false
                                let displayTotal = isVatExempt ? invoice.subtotal : invoice.total
                                
                                HStack {
                                    Text("Subtotal")
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(invoice.subtotal))
                                }
                                .font(.system(size: 14))
                                
                                if isVatExempt {
                                    Text("VAT exempt (§19 UStG)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                } else {
                                    ForEach(invoice.taxBreakdown, id: \.rate) { b in
                                        HStack {
                                            Text("VAT \(Int(b.rate))%")
                                                .foregroundColor(.secondary)
                                            Text(formatCurrency(b.amount))
                                        }
                                        .font(.system(size: 14))
                                    }
                                }
                                
                                Divider().frame(width: 150)
                                
                                HStack {
                                    Text("Total")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(formatCurrency(displayTotal))
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextEditor(text: $invoice.notes)
                            .font(.system(size: 14))
                            .frame(height: 80)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(32)
            }
            .navigationTitle(isEditing ? "Edit Invoice" : "New Invoice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingSaveTemplate = true }) {
                            Label("Save as Template", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveInvoice() }.disabled(!canSave)
                }
            }
            .alert("Save as Template", isPresented: $showingSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Cancel", role: .cancel) { templateName = "" }
                Button("Save") { saveAsTemplate() }
            } message: {
                Text("Enter a name for this template")
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClientId: $selectedClientId)
                    .environmentObject(appState)
                    .environment(\.themeColors, colors)
            }
            .onAppear {
                if !isEditing {
                    generateInvoiceNumber()
                    // Set default currency from company profile
                    if let defaultCurrency = appState.companyProfile?.defaultCurrency {
                        invoice.currency = defaultCurrency
                    }
                }
            }
        }
    }
    
    func addLineItem() {
        let vatRate = (appState.companyProfile?.isVatExempt ?? false) ? 0.0 : (appState.companyProfile?.defaultVatRate ?? 19.0)
        invoice.lineItems.append(LineItem(vatRate: vatRate))
    }
    
    func applyTemplate(_ template: InvoiceTemplate) {
        invoice.lineItems = template.lineItems
        invoice.notes = template.notes
        invoice.paymentNotes = template.paymentNotes
        if let clientId = template.defaultClientId {
            selectedClientId = clientId
        }
    }
    
    func saveAsTemplate() {
        guard !templateName.isEmpty else { return }
        var template = InvoiceTemplate()
        template.name = templateName
        template.lineItems = invoice.lineItems
        template.notes = invoice.notes
        template.paymentNotes = invoice.paymentNotes
        template.defaultClientId = selectedClientId
        appState.templates.append(template)
        appState.saveTemplates()
        templateName = ""
    }
    
    func generateInvoiceNumber() {
        if var profile = appState.companyProfile {
            invoice.invoiceNumber = profile.generateInvoiceNumber()
            profile.nextInvoiceNumber += 1
            appState.companyProfile = profile
            appState.saveCompanyProfile()
        }
    }
    
    func saveInvoice() {
        guard let clientId = selectedClientId else { return }
        invoice.clientId = clientId
        invoice.updatedAt = Date()
        
        if isEditing {
            if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                appState.invoices[i] = invoice
            }
        } else {
            appState.invoices.append(invoice)
        }
        appState.saveInvoices()
        dismiss()
    }
    
    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = invoice.currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "€0"
    }
}

struct LineItemEditor: View {
    @Binding var item: LineItem
    let currency: Currency
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Description", text: $item.description)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            TextField("Qty", value: $item.quantity, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 60)
            
            TextField("Price", value: $item.unitPrice, format: .currency(code: currency.rawValue))
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 100)
            
            Text(formatCurrency(item.total))
                .font(.system(size: 14, weight: .medium))
                .frame(width: 80, alignment: .trailing)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }
}

struct ClientPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    @Binding var selectedClientId: UUID?
    @State private var showingNewClient = false
    @State private var newClient = Client()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(colors.accent)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Select Client")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.text)
                
                Spacer()
                
                // Create New Client button
                Button(action: { 
                    newClient = Client()
                    showingNewClient = true 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(colors.mantle)
            
            // Client list
            ScrollView {
                VStack(spacing: 8) {
                    if appState.clients.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 32))
                                .foregroundColor(colors.subtext)
                            Text("No clients yet")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(colors.text)
                            Text("Add a client first from the Clients tab")
                                .font(.system(size: 13))
                                .foregroundColor(colors.subtext)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(appState.clients) { client in
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
        }
        .frame(width: 400, height: 350)
        .background(colors.base)
        .sheet(isPresented: $showingNewClient) {
            QuickClientEditorView(client: $newClient) { savedClient in
                appState.clients.append(savedClient)
                appState.saveClients()
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
    var onSave: (Client) -> Void
    
    var canSave: Bool { !client.name.isEmpty }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundColor(colors.accent)
                    .buttonStyle(.plain)
                
                Spacer()
                
                Text("New Client")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.text)
                
                Spacer()
                
                Button("Save") {
                    client.updatedAt = Date()
                    onSave(client)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(canSave ? colors.accent : colors.subtext)
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(colors.mantle)
            
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
        }
        .frame(width: 400, height: 450)
        .background(colors.base)
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
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(colors.text)
                .padding(10)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
