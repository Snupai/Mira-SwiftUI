import SwiftUI
import SwiftData

private struct ClientSummary: Identifiable {
    let id: UUID
    let name: String
    let email: String
    var initials: String {
        let words = name.split(separator: " ")
        return words.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
    }
}

struct ClientListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Query(sort: \SDClient.name) private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Binding var searchText: String
    @State private var showingNewClient = false
    @State private var selectedClient: Client?
    @State private var selection: UUID?
    @FocusState private var listFocused: Bool
    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    var body: some View {
        let clients = usesSwiftData ? sdClients.map { ClientSummary(id: $0.id, name: $0.name, email: $0.email) }
            : appState.clients.map { ClientSummary(id: $0.id, name: $0.name, email: $0.email) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let filtered = clients.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.email.localizedCaseInsensitiveContains(searchText) }
        let invoiceClientIds = usesSwiftData ? sdInvoices.compactMap { $0.client?.id } : appState.invoices.map(\.clientId)
        let counts = invoiceClientIds.reduce(into: [UUID: Int]()) { $0[$1, default: 0] += 1 }
        VStack(spacing: 0) {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(clients.isEmpty ? "No clients yet" : "No matching clients", systemImage: clients.isEmpty ? "person.2" : "magnifyingglass")
                } description: { Text(clients.isEmpty ? "Add a client to create your first invoice." : "Try another name or email address.") }
                actions: {
                    if clients.isEmpty { Button("Add your first client") { showingNewClient = true } }
                    else { Button("Clear search") { searchText = "" } }
                }
            } else {
                List(filtered, selection: $selection) { client in
                    HStack(spacing: 16) {
                        Text(client.initials).font(.subheadline.weight(.medium))
                            .frame(width: 40, height: 40).background(colors.surface1, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.name).fontWeight(.medium)
                            Text(client.email).font(.caption).foregroundStyle(colors.subtext)
                        }
                        Spacer()
                        let count = counts[client.id, default: 0]
                        Text("\(count) \(count == 1 ? "invoice" : "invoices")").foregroundStyle(colors.subtext)
                    }
                    .padding(.vertical, 6).tag(client.id)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = ids.first { Button("Open Client") { openClient(id) } }
                } primaryAction: { ids in
                    if let id = ids.first { openClient(id) }
                }
                .focusable()
                .focused($listFocused)
                .onChange(of: selection) { _, value in if value != nil { listFocused = true } }
                .onKeyPress(.return) {
                    guard let selection else { return .ignored }
                    openClient(selection)
                    return .handled
                }
                .onChange(of: filtered.map(\.id)) { _, ids in
                    if let selection, !ids.contains(selection) { self.selection = nil }
                }
            }
        }
        .background(colors.base)
        .navigationTitle("Clients")
        .searchable(text: $searchText, prompt: "Search clients…")
        .toolbar {
            ToolbarItem {
                Button("Open", systemImage: "person.crop.circle") { if let selection { openClient(selection) } }
                    .disabled(selection == nil).help("Open selected client (Return)")
            }
            ToolbarItem {
                Button("New Client", systemImage: "plus") { showingNewClient = true }
                    .miraPrimaryAction().help("New Client (⇧⌘N)")
            }
        }
        .sheet(isPresented: $showingNewClient) {
            ClientEditorView(client: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client).environmentObject(appState).environment(\.themeColors, colors)
        }
    }

    private func openClient(_ id: UUID) {
        selectedClient = usesSwiftData ? sdClients.first { $0.id == id }?.toLegacy() : appState.clients.first { $0.id == id }
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
    @State private var saveError: String?
    @State private var showingSaveError = false
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
    
    var canSave: Bool { !client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    var body: some View {
        NavigationStack {
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
                                .accessibilityLabel("Client notes")
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
            .navigationTitle(isEditing ? "Edit Client" : "New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveClient() }
                        .miraPrimaryAction()
                        .disabled(!canSave)
                }
            }
        }
        .frame(width: 520, height: 680)
        .background(colors.base)
        .alert("Client could not be saved", isPresented: $showingSaveError) {
            Button("Keep Editing", role: .cancel) { }
        } message: { Text(saveError ?? "Please try again.") }
    }
    
    func saveClient() {
        guard canSave else { return }
        client.name = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
        client.updatedAt = Date()
        do {
            if usesSwiftData {
                try saveClientToSwiftData()
            } else {
                var clients = appState.clients
                if isEditing {
                    guard let index = clients.firstIndex(where: { $0.id == client.id }) else { throw MiraPersistenceError.missingRecord }
                    clients[index] = client
                } else { clients.append(client) }
                try appState.persistClients(clients)
                appState.clients = clients
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }

    private func saveClientToSwiftData() throws {
        if isEditing {
            // Update existing client
            guard let existing = sdClients.first(where: { $0.id == client.id }) else { throw MiraPersistenceError.missingRecord }
            do {
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
        
        do { try modelContext.save() }
        catch { modelContext.rollback(); throw error }
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
            
            TextField(label, text: $text)
                .accessibilityLabel(label)
                .miraInput(colors: colors)
        }
    }
}

// MARK: - Client Detail

struct ClientDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var colors
    
    @Query private var sdClients: [SDClient]
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdProfiles: [SDCompanyProfile]
    @State private var selectedInvoice: Invoice?
    let client: Client
    @State private var showingEdit = false
    
    var currentClient: Client {
        if MigrationService.shared.useSwiftData { return sdClients.first { $0.id == client.id }?.toLegacy() ?? client }
        return appState.clients.first { $0.id == client.id } ?? client
    }
    var clientInvoices: [InvoiceSummary] {
        let exempt = MigrationService.shared.useSwiftData ? sdProfiles.first?.isVatExempt ?? false : appState.companyProfile?.isVatExempt ?? false
        if MigrationService.shared.useSwiftData {
            return sdInvoices.filter { $0.client?.id == client.id }.map { InvoiceSummary($0, isVatExempt: exempt) }.sorted { $0.issueDate > $1.issueDate }
        }
        return appState.invoices.filter { $0.clientId == client.id }.map { InvoiceSummary($0, client: currentClient, isVatExempt: exempt) }.sorted { $0.issueDate > $1.issueDate }
    }
    private func openInvoice(_ id: UUID) {
        selectedInvoice = MigrationService.shared.useSwiftData ? sdInvoices.first { $0.id == id }?.toLegacy() : appState.invoices.first { $0.id == id }
    }
    
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
                                Button { openInvoice(invoice.id) } label: {
                                HStack {
                                    Text(invoice.invoiceNumber)
                                        .font(.system(size: 14))
                                        .foregroundColor(colors.text)
                                    Spacer()
                                    Text(MiraFormat.currency(invoice.amount, invoice.currency))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(colors.text)
                                }
                                .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
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
            .sheet(item: $selectedInvoice) { invoice in
                InvoiceDetailView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
            }
            .sheet(isPresented: $showingEdit) {
                ClientEditorView(client: currentClient).environmentObject(appState)
            }
        }
    }
    

}

struct ClientListView_Previews: PreviewProvider {
    static var previews: some View {
        ClientListView(searchText: .constant("")).environmentObject(AppState())
    }
}
