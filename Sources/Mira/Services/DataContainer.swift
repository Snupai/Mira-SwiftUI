import Foundation
import SwiftData
import CloudKit
import Security
import os

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
    
    /// Shared container instance.
    ///
    /// Tries CloudKit first, falls back to local, and as an emergency last resort
    /// returns an in-memory container so the app can still surface an error to the
    /// user instead of crashing on launch. Real-app initialization in `MiraApp`
    /// uses `createWithFallback()` which also reports the underlying error.
    @MainActor
    static var shared: ModelContainer = {
        let result = createWithFallback()
        if let error = result.error {
            Log.data.fault("Persistent storage unavailable, using in-memory emergency container: \(error.localizedDescription, privacy: .public)")
        }
        return result.container
    }()

    /// Wrapper around the cascading-fallback container creation that also reports
    /// the underlying error to callers (so they can surface it in UI).
    /// Whether this process is signed with the iCloud entitlement. Ad-hoc
    /// local builds are not; asking CloudKit for a container then traps inside
    /// CoreData's mirroring setup, so those builds must stay local-only.
    static var hasCloudKitEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil)
        return value != nil
    }

    @MainActor
    static func createWithFallback() -> (container: ModelContainer, error: DataContainerError?) {
        // Try CloudKit first, but only when the binary is entitled to use it.
        if hasCloudKitEntitlement {
          do {
            let container = try createCloudKitContainer()
            Log.data.notice("SwiftData container created with CloudKit sync")
            return (container, nil)
          } catch let cloudKitError {
            Log.cloudKit.error("CloudKit container failed: \(cloudKitError.localizedDescription, privacy: .public)")
            Log.data.notice("Falling back to local-only storage")
          }
        } else {
            Log.cloudKit.notice("No iCloud entitlement in this build; using local-only storage")
        }

        // Fallback to local-only.
        do {
            let container = try createLocalContainer()
            Log.data.notice("SwiftData container created (local-only)")
            return (container, nil)
        } catch let localError {
            Log.data.fault("Failed to create local persistent container: \(localError.localizedDescription, privacy: .public)")

            // Emergency: in-memory container. Lets the app still launch and show error UI.
            do {
                let container = try createPreviewContainer()
                Log.data.fault("Using in-memory emergency container — data will NOT persist!")
                return (container, .unavailable(underlying: localError))
            } catch {
                // SwiftData itself is broken in this process — nothing more we can do.
                fatalError("Unable to create even an in-memory ModelContainer: \(error)")
            }
        }
    }
}

// MARK: - Errors

/// Errors raised by `DataContainer` when persistent storage is unavailable.
enum DataContainerError: LocalizedError {
    /// Persistent storage (CloudKit and local-only) both failed; the app is
    /// running on a non-persistent emergency container.
    case unavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unavailable(let underlying):
            return "Mira can't open its persistent storage. Your changes will not be saved.\n\n\(underlying.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unavailable:
            return "Quit Mira and try again. If the problem persists, check Console.app for details (filter by subsystem com.snupai.Mira)."
        }
    }
}

// MARK: - CloudKit Status

extension DataContainer {
    /// Check CloudKit availability
    static func checkCloudKitStatus() async -> CKAccountStatus {
        do {
            // Use default container - it should match our entitlements
            let container = CKContainer.default()
            let status = try await container.accountStatus()
            Log.cloudKit.notice("CloudKit status: \(status.rawValue) for container: \(container.containerIdentifier ?? "default", privacy: .public)")
            return status
        } catch {
            Log.cloudKit.error("CloudKit status check failed: \(error.localizedDescription, privacy: .public)")
            // Try with explicit identifier as fallback
            do {
                let status = try await CKContainer(identifier: cloudKitContainerID).accountStatus()
                Log.cloudKit.notice("CloudKit status (explicit): \(status.rawValue)")
                return status
            } catch {
                Log.cloudKit.error("CloudKit explicit check also failed: \(error.localizedDescription, privacy: .public)")
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
            profile.iban = SampleData.placeholderIBAN
            profile.bic = SampleData.placeholderBIC
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
