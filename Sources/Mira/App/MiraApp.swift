import SwiftUI

@main
struct MiraApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
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
                .keyboardShortcut("/", modifiers: .command)
            }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

extension Notification.Name {
    static let navigateTo = Notification.Name("navigateTo")
}

// MARK: - App State (JSON file storage)
@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
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
        loadData()
    }
    
    func loadData() {
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
    
    func saveCompanyProfile() {
        guard let profile = companyProfile,
              let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: profileURL)
    }
    
    func saveClients() {
        guard let data = try? JSONEncoder().encode(clients) else { return }
        try? data.write(to: clientsURL)
    }
    
    func saveInvoices() {
        guard let data = try? JSONEncoder().encode(invoices) else { return }
        try? data.write(to: invoicesURL)
    }
    
    func saveTemplates() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        try? data.write(to: templatesURL)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
