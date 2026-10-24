import SwiftUI
import SwiftData
import Sparkle
import Combine
import os
#if os(macOS)
import AppKit
#endif

@main
struct MiraApp: App {
    @StateObject private var appState = AppState()

    /// SwiftData container. Falls back through CloudKit → local → in-memory so the
    /// app can always launch and surface an error to the user; the underlying
    /// failure is captured in `containerError` and shown by `RootView`.
    let modelContainer: ModelContainer
    let containerError: DataContainerError?

    @MainActor
    init() {
        if DemoData.isEnabled, let demo = try? DemoData.makeContainer() {
            modelContainer = demo
            containerError = nil
            SnapshotRunner.runIfRequested()
            return
        }
        let result = DataContainer.createWithFallback()
        modelContainer = result.container
        containerError = result.error
    }

    var body: some Scene {
        WindowGroup {
            RootView(containerError: containerError)
                .environmentObject(appState)
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1360, height: 840)
        .commands {
            // Custom About window
            CommandGroup(replacing: .appInfo) {
                Button("About Mira") {
                    AboutWindowController.shared.showWindow()
                }
                
                CheckForUpdatesView()
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Invoice") {
                    NotificationCenter.default.post(name: .newInvoice, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Client") {
                    NotificationCenter.default.post(name: .newClient, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .sidebar) {
                Button("Overview") {
                    NotificationCenter.default.post(name: .navigateTo, object: "dashboard")
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Invoices") {
                    NotificationCenter.default.post(name: .navigateTo, object: "invoices")
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Clients") {
                    NotificationCenter.default.post(name: .navigateTo, object: "clients")
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Settings") {
                    NotificationCenter.default.post(name: .navigateTo, object: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showShortcuts, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environment(\.themeColors, ThemeManager.shared.colors(for: .light))
        }
        .modelContainer(modelContainer)
        #endif
    }
}

// MARK: - Root View (handles migration + main content)

struct RootView: View {
    /// Set when persistent-storage initialization failed and Mira is running on an
    /// in-memory emergency container. Surfaced via alert.
    let containerError: DataContainerError?

    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var isMigrating = false
    @State private var migrationError: Error?
    @State private var showMigrationError = false
    @State private var showContainerError = false

    init(containerError: DataContainerError? = nil) {
        self.containerError = containerError
    }

    var body: some View {
        Group {
            if isMigrating {
                MigrationView()
            } else {
                ContentView()
            }
        }
        .alert("Migration Error", isPresented: $showMigrationError) {
            Button("Try Again") {
                Task { await runMigration() }
            }
            Button("Skip") {
                MigrationService.shared.migrationStatus = .completed
            }
        } message: {
            Text(migrationError?.localizedDescription ?? "Unknown error during migration")
        }
        .alert("Storage Unavailable", isPresented: $showContainerError) {
            Button("Quit", role: .destructive) {
                #if os(macOS)
                NSApplication.shared.terminate(nil)
                #endif
            }
            Button("Open Console") {
                openSystemConsole()
            }
            Button("Continue Anyway", role: .cancel) {}
        } message: {
            if let error = containerError {
                Text([error.errorDescription, error.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n"))
            } else {
                Text("Mira couldn't open its persistent storage.")
            }
        }
        .task {
            if containerError != nil {
                showContainerError = true
            }
            await runMigration()
        }
    }

    @MainActor
    private func runMigration() async {
        guard MigrationService.shared.needsMigration else { return }

        isMigrating = true

        do {
            try await MigrationService.shared.migrate(context: modelContext)
            isMigrating = false
        } catch {
            migrationError = error
            showMigrationError = true
            isMigrating = false
        }
    }

    private func openSystemConsole() {
        #if os(macOS)
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
        #endif
    }
}

// MARK: - Migration View

struct MigrationView: View {
    @State private var statusText = "Preparing migration..."
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Upgrading Mira")
                .font(.title2.bold())
            
            Text(statusText)
                .foregroundStyle(.secondary)
            
            Text("Your data is being securely encrypted and migrated to the new storage format.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newInvoice = Notification.Name("newInvoice")
    static let newClient = Notification.Name("newClient")
    static let navigateTo = Notification.Name("navigateTo")
    static let showShortcuts = Notification.Name("showShortcuts")
}

// MARK: - App State (UI state, not data)

@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    // Legacy data - kept for backward compatibility during transition
    // Views should migrate to using @Query instead
    @Published var companyProfile: CompanyProfile?
    @Published var clients: [Client] = []
    @Published var invoices: [Invoice] = []
    @Published var templates: [InvoiceTemplate] = []
    
    private let fileManager = FileManager.default
    private var dataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Mira", isDirectory: true)
        do {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            Log.app.error("Failed to create app data directory: \(error.localizedDescription, privacy: .public)")
        }
        return appDir
    }
    
    private var profileURL: URL { dataDirectory.appendingPathComponent("profile.json") }
    private var clientsURL: URL { dataDirectory.appendingPathComponent("clients.json") }
    private var invoicesURL: URL { dataDirectory.appendingPathComponent("invoices.json") }
    private var templatesURL: URL { dataDirectory.appendingPathComponent("templates.json") }
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Only load legacy data if migration hasn't completed
        // This keeps the app working during the transition period
        if MigrationService.shared.migrationStatus != .completed {
            loadLegacyData()
        }
    }
    
    private func loadLegacyData() {
        // Load company profile
        if fileManager.fileExists(atPath: profileURL.path) {
            do {
                let data = try Data(contentsOf: profileURL)
                self.companyProfile = try JSONDecoder().decode(CompanyProfile.self, from: data)
            } catch {
                Log.app.error("Failed to load legacy profile.json: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Load clients
        if fileManager.fileExists(atPath: clientsURL.path) {
            do {
                let data = try Data(contentsOf: clientsURL)
                self.clients = try JSONDecoder().decode([Client].self, from: data)
            } catch {
                Log.app.error("Failed to load legacy clients.json: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Load invoices
        if fileManager.fileExists(atPath: invoicesURL.path) {
            do {
                let data = try Data(contentsOf: invoicesURL)
                self.invoices = try JSONDecoder().decode([Invoice].self, from: data)
            } catch {
                Log.app.error("Failed to load legacy invoices.json: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Load templates
        if fileManager.fileExists(atPath: templatesURL.path) {
            do {
                let data = try Data(contentsOf: templatesURL)
                self.templates = try JSONDecoder().decode([InvoiceTemplate].self, from: data)
            } catch {
                Log.app.error("Failed to load legacy templates.json: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // Legacy save methods - deprecated, will be removed after full migration
    func saveCompanyProfile() {
        guard MigrationService.shared.needsMigration else { return }
        guard let profile = companyProfile else { return }
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: profileURL)
        } catch {
            Log.app.error("Failed to save legacy profile.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveClients() {
        guard MigrationService.shared.needsMigration else { return }
        do {
            let data = try JSONEncoder().encode(clients)
            try data.write(to: clientsURL)
        } catch {
            Log.app.error("Failed to save legacy clients.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveInvoices() {
        guard MigrationService.shared.needsMigration else { return }
        do {
            let data = try JSONEncoder().encode(invoices)
            try data.write(to: invoicesURL)
        } catch {
            Log.app.error("Failed to save legacy invoices.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveTemplates() {
        guard MigrationService.shared.needsMigration else { return }
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: templatesURL)
        } catch {
            Log.app.error("Failed to save legacy templates.json: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
