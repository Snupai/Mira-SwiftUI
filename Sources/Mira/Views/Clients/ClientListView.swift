import SwiftUI
import SwiftData
import os

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
                        ClientAvatar(name: currentClient.name, size: 60)
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
