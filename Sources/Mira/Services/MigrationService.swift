import Foundation
import SwiftData
import os

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
    
    /// Whether to use SwiftData (migration completed OR no legacy data exists)
    var useSwiftData: Bool {
        migrationStatus == .completed || !needsMigration
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
                Log.migration.info("Backed up \(fileName, privacy: .public)")
            }
        }

        Log.migration.notice("Backup completed to: \(backupDir.path, privacy: .public)")
    }
    
    // MARK: - Load Legacy Data
    
    func loadLegacyProfile() -> CompanyProfile? {
        let url = appSupportURL.appendingPathComponent("profile.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode(CompanyProfile.self, from: data)
        } catch {
            Log.migration.error("Failed to load legacy profile.json: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadLegacyClients() -> [Client] {
        let url = appSupportURL.appendingPathComponent("clients.json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode([Client].self, from: data)
        } catch {
            Log.migration.error("Failed to load legacy clients.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func loadLegacyInvoices() -> [Invoice] {
        let url = appSupportURL.appendingPathComponent("invoices.json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode([Invoice].self, from: data)
        } catch {
            Log.migration.error("Failed to load legacy invoices.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func loadLegacyTemplates() -> [InvoiceTemplate] {
        let url = appSupportURL.appendingPathComponent("templates.json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode([InvoiceTemplate].self, from: data)
        } catch {
            Log.migration.error("Failed to load legacy templates.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    // MARK: - Migration
    
    /// Perform full migration from JSON to SwiftData
    @MainActor
    func migrate(context: ModelContext) async throws {
        guard needsMigration else {
            Log.migration.info("No migration needed")
            return
        }

        migrationStatus = .inProgress

        do {
            // Step 1: Backup
            Log.migration.notice("Creating backup")
            try backupLegacyData()

            // Step 2: Load legacy data
            Log.migration.notice("Loading legacy data")
            let legacyProfile = loadLegacyProfile()
            let legacyClients = loadLegacyClients()
            let legacyInvoices = loadLegacyInvoices()
            let legacyTemplates = loadLegacyTemplates()

            Log.migration.info("Legacy data: profile=\(legacyProfile != nil ? "yes" : "no", privacy: .public), clients=\(legacyClients.count), invoices=\(legacyInvoices.count), templates=\(legacyTemplates.count)")

            // Step 3: Migrate profile
            if let profile = legacyProfile {
                Log.migration.notice("Migrating profile")
                let sdProfile = SDCompanyProfile(from: profile)
                context.insert(sdProfile)
            }

            // Step 4: Migrate clients (need to keep track for invoice relationships)
            Log.migration.notice("Migrating clients (\(legacyClients.count))")
            var clientMap: [UUID: SDClient] = [:]
            for client in legacyClients {
                let sdClient = SDClient(from: client)
                context.insert(sdClient)
                clientMap[client.id] = sdClient
            }

            // Step 5: Migrate invoices
            Log.migration.notice("Migrating invoices (\(legacyInvoices.count))")
            for invoice in legacyInvoices {
                let client = clientMap[invoice.clientId]
                let sdInvoice = SDInvoice(from: invoice, client: client)
                context.insert(sdInvoice)
            }

            // Step 6: Migrate templates
            Log.migration.notice("Migrating templates (\(legacyTemplates.count))")
            for template in legacyTemplates {
                let defaultClient = template.defaultClientId.flatMap { clientMap[$0] }
                let sdTemplate = SDInvoiceTemplate(from: template, defaultClient: defaultClient)
                context.insert(sdTemplate)
            }

            // Step 7: Save
            Log.migration.notice("Saving to SwiftData")
            try context.save()

            // Step 8: Mark complete
            migrationStatus = .completed
            Log.migration.notice("Migration completed successfully")

            // Step 9: Handle legacy files (rename or delete)
            if shouldDeleteLegacyFiles {
                try deleteLegacyFiles()
            } else {
                try renameLegacyFiles()
            }

        } catch {
            migrationStatus = .failed
            Log.migration.error("Migration failed: \(error.localizedDescription, privacy: .public)")
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
                Log.migration.info("Renamed \(fileName, privacy: .public) → \(fileName, privacy: .public).migrated")
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
                Log.migration.info("Deleted legacy file: \(fileName, privacy: .public)")
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
        
        Log.migration.notice("Rolling back to: \(latestBackup.lastPathComponent, privacy: .public)")

        let filesToRestore = ["profile.json", "clients.json", "invoices.json", "templates.json"]

        for fileName in filesToRestore {
            let sourceURL = latestBackup.appendingPathComponent(fileName)
            let destURL = appSupportURL.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: sourceURL.path) {
                try? fileManager.removeItem(at: destURL)
                try fileManager.copyItem(at: sourceURL, to: destURL)
                Log.migration.info("Restored \(fileName, privacy: .public)")
            }
        }

        migrationStatus = .notStarted
        Log.migration.notice("Rollback completed")
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
