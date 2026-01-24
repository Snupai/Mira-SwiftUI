import SwiftUI
import SwiftData

struct ClientListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData queries
    @Query(sort: \SDClient.name) private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    
    @State private var searchText = ""
    @State private var showingNewClient = false
    @State private var selectedClient: Client?
    
    // Use SwiftData if migrated or no legacy data exists
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    private var allClients: [Client] {
        if usesSwiftData {
            return sdClients.map { $0.toLegacy() }
        }
        return appState.clients
    }
    
    private var allInvoices: [Invoice] {
        if usesSwiftData {
            return sdInvoices.map { $0.toLegacy() }
        }
        return appState.invoices
    }
    
    var filteredClients: [Client] {
        let clients = allClients.sorted { $0.name < $1.name }
        if searchText.isEmpty { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func invoiceCount(for clientId: UUID) -> Int {
        allInvoices.filter { $0.clientId == clientId }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clients")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(colors.text)
                Spacer()
                Button(action: { showingNewClient = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(colors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colors.subtext)
                    .font(.system(size: 14))
                TextField("Search clients...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(colors.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colors.surface0)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 200)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
            
            Divider().background(colors.surface1)
            
            // List
            if filteredClients.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No clients")
                        .font(.system(size: 17))
                        .foregroundColor(colors.subtext)
                    if allClients.isEmpty {
                        Button("Add your first client") { showingNewClient = true }
                            .buttonStyle(.plain)
                            .foregroundColor(colors.accent)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredClients) { client in
                            ClientRow(client: client, invoiceCount: appState.invoices.filter { $0.clientId == client.id }.count, colors: colors)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedClient = client }
                            Divider().background(colors.surface0)
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .background(colors.base)
        .sheet(isPresented: $showingNewClient) {
            ClientEditorView(client: nil).environmentObject(appState)
        }
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client).environmentObject(appState)
        }
    }
}

struct ClientRow: View {
    let client: Client
    let invoiceCount: Int
    let colors: ThemeColors
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Text(client.initials)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.text)
                .frame(width: 40, height: 40)
                .background(colors.surface1)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colors.text)
                Text(client.email)
                    .font(.system(size: 13))
                    .foregroundColor(colors.subtext)
            }
            
            Spacer()
            
            Text("\(invoiceCount) invoices")
                .font(.system(size: 13))
                .foregroundColor(colors.subtext)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Client Avatar

struct ClientAvatar: View {
    let client: Client
    var size: CGFloat = 40
    @Environment(\.themeColors) var colors
    
    var body: some View {
        Text(client.initials)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(colors.text)
            .frame(width: size, height: size)
            .background(colors.surface1)
            .clipShape(Circle())
    }
}

// MARK: - Client Editor

struct ClientEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sdClients: [SDClient]
    
    @State private var client: Client
    let isEditing: Bool
    
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    init(client: Client?) {
        if let client = client {
            _client = State(initialValue: client)
            isEditing = true
        } else {
            _client = State(initialValue: Client())
            isEditing = false
        }
    }
    
    var canSave: Bool { !client.name.isEmpty }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(colors.subtext)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(isEditing ? "Edit Client" : "New Client")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.text)
                
                Spacer()
                
                Button(action: { saveClient() }) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(canSave ? colors.accent : colors.subtext)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(colors.mantle)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Basic Info
                    FormSection(title: "Basic Information", colors: colors) {
                        VStack(spacing: 16) {
                            FormField(label: "Company / Name", text: $client.name, required: true, colors: colors)
                            FormField(label: "Contact Person", text: $client.contactPerson, colors: colors)
                            HStack(spacing: 16) {
                                FormField(label: "Email", text: $client.email, colors: colors)
                                FormField(label: "Phone", text: $client.phone, colors: colors)
                            }
                        }
                    }
                    
                    // Address
                    FormSection(title: "Address", colors: colors) {
                        VStack(spacing: 16) {
                            FormField(label: "Street", text: $client.street, colors: colors)
                            HStack(spacing: 16) {
                                FormField(label: "Postal Code", text: $client.postalCode, colors: colors)
                                    .frame(width: 120)
                                FormField(label: "City", text: $client.city, colors: colors)
                            }
                            FormField(label: "Country", text: $client.country, colors: colors)
                        }
                    }
                    
                    // Tax
                    FormSection(title: "Tax", colors: colors) {
                        FormField(label: "VAT ID", text: $client.vatId, colors: colors)
                    }
                    
                    // Notes
                    FormSection(title: "Notes", colors: colors) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextEditor(text: $client.notes)
                                .font(.system(size: 14))
                                .foregroundColor(colors.text)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(height: 100)
                                .background(colors.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .background(colors.base)
    }
    
    func saveClient() {
        client.updatedAt = Date()
        
        if usesSwiftData {
            saveClientToSwiftData()
        } else {
            // Legacy save
            if isEditing {
                if let i = appState.clients.firstIndex(where: { $0.id == client.id }) {
                    appState.clients[i] = client
                }
            } else {
                appState.clients.append(client)
            }
            appState.saveClients()
        }
        dismiss()
    }
    
    private func saveClientToSwiftData() {
        if isEditing {
            // Update existing client
            if let existing = sdClients.first(where: { $0.id == client.id }) {
                existing.name = client.name
                existing.contactPerson = client.contactPerson
                existing.email = client.email
                existing.phone = client.phone
                existing.street = client.street
                existing.city = client.city
                existing.postalCode = client.postalCode
                existing.country = client.country
                existing.vatId = client.vatId
                existing.taxNumber = client.taxNumber
                existing.defaultCurrencyRaw = client.defaultCurrency?.rawValue
                existing.defaultPaymentTermsDays = client.defaultPaymentTermsDays
                existing.defaultVatRate = client.defaultVatRate
                existing.language = client.language
                existing.notes = client.notes
                existing.updatedAt = Date()
            }
        } else {
            // Create new client
            let sdClient = SDClient(from: client)
            modelContext.insert(sdClient)
        }
        
        do {
            try modelContext.save()
            print("✅ Saved client to SwiftData")
        } catch {
            print("⚠️ SwiftData save failed: \(error)")
        }
    }
}

// MARK: - Form Components

struct FormSection<Content: View>: View {
    let title: String
    let colors: ThemeColors
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colors.subtext)
            
            content()
                .padding(16)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    var required: Bool = false
    let colors: ThemeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.subtext)
                if required {
                    Text("*")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Client Detail

struct ClientDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    
    let client: Client
    @State private var showingEdit = false
    
    var currentClient: Client { appState.clients.first { $0.id == client.id } ?? client }
    var clientInvoices: [Invoice] { appState.invoices.filter { $0.clientId == client.id } }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 16) {
                        ClientAvatar(client: currentClient, size: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentClient.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(colors.text)
                            Text(currentClient.email)
                                .font(.system(size: 14))
                                .foregroundColor(colors.subtext)
                        }
                    }
                    
                    if !currentClient.street.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.subtext)
                            Text(currentClient.formattedAddress)
                                .font(.system(size: 14))
                                .foregroundColor(colors.text)
                        }
                    }
                    
                    if !clientInvoices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Invoices")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.subtext)
                            
                            ForEach(clientInvoices) { invoice in
                                HStack {
                                    Text(invoice.invoiceNumber)
                                        .font(.system(size: 14))
                                        .foregroundColor(colors.text)
                                    Spacer()
                                    Text(formatCurrency(invoice.total, currency: invoice.currency))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(colors.text)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(32)
            }
            .background(colors.base)
            .navigationTitle("Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEdit = true }
                }
            }
            .sheet(isPresented: $showingEdit) {
                ClientEditorView(client: currentClient).environmentObject(appState)
            }
        }
    }
    
    func formatCurrency(_ value: Double, currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }
}

struct ClientListView_Previews: PreviewProvider {
    static var previews: some View {
        ClientListView().environmentObject(AppState())
    }
}
