import SwiftUI
import SwiftData
import os

/// Create or edit a client. Presented as a sheet from the client list and
/// from the invoice editor ("New client…").
struct ClientEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sdClients: [SDClient]

    @State private var client: Client
    @State private var saveError: String?
    let isEditing: Bool
    var onSaved: ((Client) -> Void)? = nil

    private enum Field: Hashable { case name }
    @FocusState private var focus: Field?

    init(client: Client?, onSaved: ((Client) -> Void)? = nil) {
        _client = State(initialValue: client ?? Client())
        isEditing = client != nil
        self.onSaved = onSaved
    }

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }
    private var canSave: Bool { !client.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    TextField("Company or name", text: $client.name)
                        .focused($focus, equals: .name)
                    TextField("Contact person", text: $client.contactPerson)
                    TextField("Email", text: $client.email)
                        .textContentType(.emailAddress)
                    TextField("Phone", text: $client.phone)
                        .textContentType(.telephoneNumber)
                }

                Section("Address") {
                    TextField("Street", text: $client.street)
                    HStack {
                        TextField("Postal code", text: $client.postalCode)
                            .frame(width: 120)
                        TextField("City", text: $client.city)
                    }
                    TextField("Country", text: $client.country)
                }

                Section {
                    TextField("VAT ID", text: $client.vatId)
                    TextField("Tax number", text: $client.taxNumber)
                } header: {
                    Text("Tax")
                } footer: {
                    Text("Shown on invoices when present. Required for reverse-charge invoices to EU businesses.")
                }

                Section("Invoice defaults") {
                    Picker("Currency", selection: $client.defaultCurrency) {
                        Text("Same as yours").tag(Currency?.none)
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.rawValue)").tag(Currency?.some(currency))
                        }
                    }
                    Picker("Payment terms", selection: $client.defaultPaymentTermsDays) {
                        Text("Same as yours").tag(Int?.none)
                        ForEach([7, 14, 30, 60], id: \.self) { days in
                            Text("\(days) days").tag(Int?.some(days))
                        }
                    }
                    Picker("Language", selection: $client.language) {
                        Text("Deutsch").tag("de")
                        Text("English").tag("en")
                    }
                }

                Section("Notes") {
                    TextField("Internal notes, not shown on invoices", text: $client.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit client" : "New client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add client") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Couldn't save client", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .frame(width: 520, height: 640)
        .onAppear { if !isEditing { focus = .name } }
    }

    private func save() {
        client.updatedAt = Date()
        if usesSwiftData {
            if isEditing, let existing = sdClients.first(where: { $0.id == client.id }) {
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
            } else {
                modelContext.insert(SDClient(from: client))
            }
            do {
                try modelContext.save()
            } catch {
                Log.data.error("Client save failed: \(error.localizedDescription, privacy: .public)")
                saveError = error.localizedDescription
                return
            }
        } else {
            if let index = appState.clients.firstIndex(where: { $0.id == client.id }) {
                appState.clients[index] = client
            } else {
                appState.clients.append(client)
            }
            appState.saveClients()
        }
        onSaved?(client)
        dismiss()
    }
}
