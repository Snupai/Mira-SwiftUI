import Foundation
import SwiftData
import CloudKit

/// SwiftData container configuration with CloudKit sync
enum DataContainer {
    
    /// All SwiftData model types
    static let modelTypes: [any PersistentModel.Type] = [
        SDCompanyProfile.self,
        SDClient.self,
        SDInvoice.self,
        SDInvoiceTemplate.self
    ]
    
    /// Schema for all models
    static var schema: Schema {
        Schema(modelTypes)
    }
    
    /// iCloud container identifier
    /// ⚠️ You need to create this container in Apple Developer Portal
    static let cloudKitContainerID = "iCloud.com.snupai.Mira"
    
    /// Create ModelContainer with CloudKit sync enabled
    static func createCloudKitContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Mira",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
    
    /// Create ModelContainer for local-only storage (no CloudKit)
    static func createLocalContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Mira",  // Same name as CloudKit container to share the same store
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
    
    /// Create in-memory container for testing/previews
    static func createPreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Mira-Preview",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
    
    /// Isolated sample store for UI verification; never opens the user's database.
    @MainActor
    static func createReviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration("Mira-Review", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let profile = SDCompanyProfile()
        profile.companyName = "Mira Studio"
        profile.ownerName = "Alex Example"
        profile.email = "alex@example.com"
        profile.street = "Example Street 1"
        profile.city = "Berlin"
        profile.postalCode = "10115"
        profile.defaultCurrency = .gbp
        profile.isVatExempt = true
        profile.defaultVatRate = 0
        profile.defaultPaymentTermsDays = 30
        profile.nextInvoiceNumber = 31
        context.insert(profile)
        let clients = ["Acme Studio", "Northwind", "Orbit Design"].map { name in
            let client = SDClient()
            client.name = name
            client.email = name.lowercased().replacingOccurrences(of: " ", with: ".") + "@example.com"
            context.insert(client)
            return client
        }
        for index in 0..<30 {
            let invoice = SDInvoice()
            invoice.invoiceNumber = "INV-2026-" + String(format: "%04d", index + 1)
            invoice.client = clients[index % clients.count]
            invoice.currency = index % 4 == 0 ? .eur : .gbp
            invoice.lineItems = [SDLineItem(itemDescription: "Design services", quantity: 4, unit: "hours", unitPrice: Double(100 + index * 5), vatRate: 0)]
            invoice.issueDate = Calendar.current.date(byAdding: .day, value: -index * 5, to: Date()) ?? Date()
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: index % 2 == 0 ? -3 : 10, to: Date()) ?? Date()
            invoice.createdAt = invoice.issueDate
            invoice.status = index % 3 == 0 ? .draft : index % 3 == 1 ? .sent : .paid
            if invoice.status == .paid {
                invoice.paidAt = Calendar.current.date(byAdding: .day, value: -index * 3, to: Date())
                if invoice.currency != .gbp { invoice.paidAmountInBaseCurrency = invoice.subtotal * 0.85 }
            }
            context.insert(invoice)
        }
        try context.save()
        return container
    }

    /// Shared container instance
    /// Uses CloudKit if available, falls back to local
    @MainActor
    static var shared: ModelContainer = {
        do {
            // Try CloudKit first
            let container = try createCloudKitContainer()
            print("✅ SwiftData container created with CloudKit sync")
            return container
        } catch {
            print("⚠️ CloudKit container failed: \(error)")
            print("⚠️ Falling back to local-only storage")
            
            // Fallback to local
            do {
                let container = try createLocalContainer()
                print("✅ SwiftData container created (local-only)")
                return container
            } catch {
                fatalError("❌ Failed to create any ModelContainer: \(error)")
            }
        }
    }()
}

// MARK: - CloudKit Status

extension DataContainer {
    /// Check CloudKit availability
    static func checkCloudKitStatus() async -> CKAccountStatus {
        do {
            // Use default container - it should match our entitlements
            let container = CKContainer.default()
            let status = try await container.accountStatus()
            print("✅ CloudKit status: \(status.rawValue) for container: \(container.containerIdentifier ?? "default")")
            return status
        } catch {
            print("⚠️ CloudKit status check failed: \(error.localizedDescription)")
            // Try with explicit identifier as fallback
            do {
                let status = try await CKContainer(identifier: cloudKitContainerID).accountStatus()
                print("✅ CloudKit status (explicit): \(status.rawValue)")
                return status
            } catch {
                print("❌ CloudKit explicit check also failed: \(error.localizedDescription)")
                return .couldNotDetermine
            }
        }
    }
    
    /// Human-readable CloudKit status
    static func cloudKitStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "iCloud Available ✓"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "iCloud Restricted"
        case .couldNotDetermine:
            return "Could not determine iCloud status"
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        @unknown default:
            return "Unknown iCloud status"
        }
    }
}

// MARK: - Preview Helpers

extension DataContainer {
    /// Preview container with sample data
    @MainActor
    static var preview: ModelContainer = {
        do {
            let container = try createPreviewContainer()
            let context = container.mainContext
            
            // Add sample profile
            let profile = SDCompanyProfile()
            profile.companyName = "Snupai Studios"
            profile.ownerName = "Snupai"
            profile.email = "hello@snupai.dev"
            profile.iban = "DE89370400440532013000"
            profile.bic = "COBADEFFXXX"
            context.insert(profile)
            
            // Add sample client
            let client = SDClient()
            client.name = "Acme Corp"
            client.email = "billing@acme.com"
            client.city = "Berlin"
            context.insert(client)
            
            // Add sample invoice
            let invoice = SDInvoice()
            invoice.invoiceNumber = "INV-2026-0001"
            invoice.client = client
            invoice.lineItems = [
                SDLineItem(itemDescription: "Development Services", quantity: 10, unit: "hours", unitPrice: 120, vatRate: 19)
            ]
            context.insert(invoice)
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
