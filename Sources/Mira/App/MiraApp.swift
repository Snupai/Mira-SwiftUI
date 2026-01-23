import SwiftUI
import SwiftData
import Sparkle
import Combine

@main
struct MiraApp: App {
    @StateObject private var appState = AppState()
    
    /// SwiftData container with CloudKit sync
    let modelContainer: ModelContainer
    
    init() {
        // Initialize SwiftData container (local-only for now during development)
        do {
            modelContainer = try DataContainer.createLocalContainer()
            print("✅ SwiftData container initialized (local-only)")
        } catch {
            fatalError("❌ Failed to create ModelContainer: \(error)")
        }
        
        /* Enable CloudKit after schema is stable:
        do {
            modelContainer = try DataContainer.createCloudKitContainer()
            print("✅ SwiftData container initialized with CloudKit")
        } catch {
            print("⚠️ CloudKit failed, falling back to local: \(error)")
            do {
                modelContainer = try DataContainer.createLocalContainer()
                print("✅ SwiftData container initialized (local-only)")
            } catch {
                fatalError("❌ Failed to create ModelContainer: \(error)")
            }
        }
        */
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
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
                Button("Dashboard") {
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
        }
        .modelContainer(modelContainer)
        #endif
    }
}

// MARK: - Root View (handles migration + main content)

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    
    @State private var isMigrating = false
    @State private var migrationError: Error?
    @State private var showMigrationError = false
    
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
        .task {
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
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
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
        if let data = try? Data(contentsOf: profileURL),
           let profile = try? JSONDecoder().decode(CompanyProfile.self, from: data) {
            self.companyProfile = profile
        }
        
        // Load clients
        if let data = try? Data(contentsOf: clientsURL),
           let clients = try? JSONDecoder().decode([Client].self, from: data) {
            self.clients = clients
        }
        
        // Load invoices
        if let data = try? Data(contentsOf: invoicesURL),
           let invoices = try? JSONDecoder().decode([Invoice].self, from: data) {
            self.invoices = invoices
        }
        
        // Load templates
        if let data = try? Data(contentsOf: templatesURL),
           let templates = try? JSONDecoder().decode([InvoiceTemplate].self, from: data) {
            self.templates = templates
        }
    }
    
    // Legacy save methods - deprecated, will be removed after full migration
    func saveCompanyProfile() {
        guard MigrationService.shared.migrationStatus != .completed else {
            print("⚠️ saveCompanyProfile called but migration is complete - use SwiftData instead")
            return
        }
        guard let profile = companyProfile,
              let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: profileURL)
    }
    
    func saveClients() {
        guard MigrationService.shared.migrationStatus != .completed else {
            print("⚠️ saveClients called but migration is complete - use SwiftData instead")
            return
        }
        guard let data = try? JSONEncoder().encode(clients) else { return }
        try? data.write(to: clientsURL)
    }
    
    func saveInvoices() {
        guard MigrationService.shared.migrationStatus != .completed else {
            print("⚠️ saveInvoices called but migration is complete - use SwiftData instead")
            return
        }
        guard let data = try? JSONEncoder().encode(invoices) else { return }
        try? data.write(to: invoicesURL)
    }
    
    func saveTemplates() {
        guard MigrationService.shared.migrationStatus != .completed else {
            print("⚠️ saveTemplates called but migration is complete - use SwiftData instead")
            return
        }
        guard let data = try? JSONEncoder().encode(templates) else { return }
        try? data.write(to: templatesURL)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
