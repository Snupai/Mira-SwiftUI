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
            "Mira-Local",
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
            return try await CKContainer(identifier: cloudKitContainerID).accountStatus()
        } catch {
            print("⚠️ CloudKit status check failed: \(error)")
            return .couldNotDetermine
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
