import Foundation
import SwiftData

/// Service to migrate data from legacy JSON storage to SwiftData
final class MigrationService {
    static let shared = MigrationService()
    
    private let fileManager = FileManager.default
    private let jsonDecoder = JSONDecoder()
    
    private var appSupportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mira")
    }
    
    private var backupURL: URL {
        appSupportURL.appendingPathComponent("Backup")
    }
    
    private init() {}
    
    // MARK: - Migration Status
    
    enum MigrationStatus: String {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed = "completed"
        case failed = "failed"
    }
    
    var migrationStatus: MigrationStatus {
        get {
            let status = UserDefaults.standard.string(forKey: "mira.migrationStatus") ?? "not_started"
            return MigrationStatus(rawValue: status) ?? .notStarted
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "mira.migrationStatus")
        }
    }
    
    var needsMigration: Bool {
        // Check if legacy JSON files exist and migration hasn't completed
        let profileExists = fileManager.fileExists(atPath: appSupportURL.appendingPathComponent("profile.json").path)
        return profileExists && migrationStatus != .completed
    }
    
    // MARK: - Backup
    
    /// Backup all JSON files before migration
    func backupLegacyData() throws {
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupDir = backupURL.appendingPathComponent("backup_\(timestamp)")
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let filesToBackup = ["profile.json", "clients.json", "invoices.json", "templates.json"]
        
        for fileName in filesToBackup {
            let sourceURL = appSupportURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: sourceURL.path) {
                let destURL = backupDir.appendingPathComponent(fileName)
                try fileManager.copyItem(at: sourceURL, to: destURL)
                print("✅ Backed up \(fileName)")
            }
        }
        
        print("✅ Backup completed to: \(backupDir.path)")
    }
    
    // MARK: - Load Legacy Data
    
    func loadLegacyProfile() -> CompanyProfile? {
        let url = appSupportURL.appendingPathComponent("profile.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? jsonDecoder.decode(CompanyProfile.self, from: data)
    }
    
    func loadLegacyClients() -> [Client] {
        let url = appSupportURL.appendingPathComponent("clients.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? jsonDecoder.decode([Client].self, from: data)) ?? []
    }
    
    func loadLegacyInvoices() -> [Invoice] {
        let url = appSupportURL.appendingPathComponent("invoices.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? jsonDecoder.decode([Invoice].self, from: data)) ?? []
    }
    
    func loadLegacyTemplates() -> [InvoiceTemplate] {
        let url = appSupportURL.appendingPathComponent("templates.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? jsonDecoder.decode([InvoiceTemplate].self, from: data)) ?? []
    }
    
    // MARK: - Migration
    
    /// Perform full migration from JSON to SwiftData
    @MainActor
    func migrate(context: ModelContext) async throws {
        guard needsMigration else {
            print("ℹ️ No migration needed")
            return
        }
        
        migrationStatus = .inProgress
        
        do {
            // Step 1: Backup
            print("📦 Creating backup...")
            try backupLegacyData()
            
            // Step 2: Load legacy data
            print("📖 Loading legacy data...")
            let legacyProfile = loadLegacyProfile()
            let legacyClients = loadLegacyClients()
            let legacyInvoices = loadLegacyInvoices()
            let legacyTemplates = loadLegacyTemplates()
            
            print("  - Profile: \(legacyProfile != nil ? "✓" : "✗")")
            print("  - Clients: \(legacyClients.count)")
            print("  - Invoices: \(legacyInvoices.count)")
            print("  - Templates: \(legacyTemplates.count)")
            
            // Step 3: Migrate profile
            if let profile = legacyProfile {
                print("🔄 Migrating profile...")
                let sdProfile = SDCompanyProfile(from: profile)
                context.insert(sdProfile)
            }
            
            // Step 4: Migrate clients (need to keep track for invoice relationships)
            print("🔄 Migrating clients...")
            var clientMap: [UUID: SDClient] = [:]
            for client in legacyClients {
                let sdClient = SDClient(from: client)
                context.insert(sdClient)
                clientMap[client.id] = sdClient
            }
            
            // Step 5: Migrate invoices
            print("🔄 Migrating invoices...")
            for invoice in legacyInvoices {
                let client = clientMap[invoice.clientId]
                let sdInvoice = SDInvoice(from: invoice, client: client)
                context.insert(sdInvoice)
            }
            
            // Step 6: Migrate templates
            print("🔄 Migrating templates...")
            for template in legacyTemplates {
                let defaultClient = template.defaultClientId.flatMap { clientMap[$0] }
                let sdTemplate = SDInvoiceTemplate(from: template, defaultClient: defaultClient)
                context.insert(sdTemplate)
            }
            
            // Step 7: Save
            print("💾 Saving to SwiftData...")
            try context.save()
            
            // Step 8: Mark complete
            migrationStatus = .completed
            print("✅ Migration completed successfully!")
            
            // Step 9: Handle legacy files (rename or delete)
            if shouldDeleteLegacyFiles {
                try deleteLegacyFiles()
            } else {
                try renameLegacyFiles()
            }
            
        } catch {
            migrationStatus = .failed
            print("❌ Migration failed: \(error)")
            throw error
        }
    }
    
    /// Whether to delete legacy JSON after migration
    var shouldDeleteLegacyFiles: Bool {
        UserDefaults.standard.bool(forKey: "mira.deleteLegacyAfterMigration")
    }
    
    /// Rename legacy files to .migrated extension
    private func renameLegacyFiles() throws {
        let filesToRename = ["profile.json", "clients.json", "invoices.json", "templates.json"]
        
        for fileName in filesToRename {
            let sourceURL = appSupportURL.appendingPathComponent(fileName)
            let destURL = appSupportURL.appendingPathComponent("\(fileName).migrated")
            
            if fileManager.fileExists(atPath: sourceURL.path) {
                // Remove existing .migrated file if it exists
                try? fileManager.removeItem(at: destURL)
                try fileManager.moveItem(at: sourceURL, to: destURL)
                print("📁 Renamed \(fileName) → \(fileName).migrated")
            }
        }
    }
    
    /// Delete legacy JSON files after migration
    private func deleteLegacyFiles() throws {
        let filesToDelete = ["profile.json", "clients.json", "invoices.json", "templates.json"]
        
        for fileName in filesToDelete {
            let url = appSupportURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                print("🗑️ Deleted legacy file: \(fileName)")
            }
        }
    }
    
    // MARK: - Rollback
    
    /// Restore from backup (in case of issues)
    func rollbackToLatestBackup() throws {
        // Find latest backup
        let backups = try fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("backup_") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        
        guard let latestBackup = backups.first else {
            throw MigrationError.noBackupFound
        }
        
        print("🔄 Rolling back to: \(latestBackup.lastPathComponent)")
        
        let filesToRestore = ["profile.json", "clients.json", "invoices.json", "templates.json"]
        
        for fileName in filesToRestore {
            let sourceURL = latestBackup.appendingPathComponent(fileName)
            let destURL = appSupportURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: sourceURL.path) {
                try? fileManager.removeItem(at: destURL)
                try fileManager.copyItem(at: sourceURL, to: destURL)
                print("✅ Restored \(fileName)")
            }
        }
        
        migrationStatus = .notStarted
        print("✅ Rollback completed")
    }
}

// MARK: - Errors

enum MigrationError: LocalizedError {
    case noBackupFound
    case migrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noBackupFound:
            return "No backup found to restore from"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        }
    }
}
