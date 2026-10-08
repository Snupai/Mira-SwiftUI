import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    // SwiftData query for company profile
    @Query private var profiles: [SDCompanyProfile]
    
    /// Check if setup is complete (works with both old and new data)
    private var isSetupComplete: Bool {
        if MigrationService.shared.useSwiftData {
            return profiles.first != nil && appState.hasCompletedOnboarding
        }
        return appState.companyProfile != nil && appState.hasCompletedOnboarding
    }
    
    var body: some View {
        Group {
            if isSetupComplete {
                MainView()
            } else {
                OnboardingContainerView()
            }
        }
        .modifier(MiraThemeStyle())
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 600)
        #endif
    }
}

/// Theme document/content surfaces while leaving native window chrome adaptive.
struct MiraThemeStyle: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let colors = themeManager.colors(for: colorScheme)
        content
            .environment(\.themeColors, colors)
            .tint(colors.accent)
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: Tab? = .invoices
    @State private var invoiceBrowsingState = InvoiceBrowsingState()
    @State private var clientSearchText = ""
    
    var colors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }
    @State private var showingNewInvoice = false
    @State private var showingNewClient = false
    @State private var showingShortcuts = false
    
    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case invoices = "Invoices"
        case clients = "Clients"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .invoices: return "doc.text"
            case .clients: return "person.2"
            case .settings: return "gearshape"
            }
        }
        
        var shortcut: KeyEquivalent? {
            switch self {
            case .dashboard: return "1"
            case .invoices: return "2"
            case .clients: return "3"
            case .settings: return ","
            }
        }
    }
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("Mira")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
        } detail: {
            content(for: selectedTab ?? .invoices)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle((selectedTab ?? .invoices).rawValue)
        }
        // Keyboard shortcut handlers
        .onReceive(NotificationCenter.default.publisher(for: .newInvoice)) { _ in
            showingNewInvoice = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newClient)) { _ in
            showingNewClient = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            if let target = notification.object as? String {
                switch target {
                case "dashboard": selectedTab = .dashboard
                case "invoices": selectedTab = .invoices
                case "clients": selectedTab = .clients
                case "settings": selectedTab = .settings
                default: break
                }
            }
        }
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState)
        }
        .sheet(isPresented: $showingNewClient) {
            ClientEditorView(client: nil).environmentObject(appState)
        }
        .sheet(isPresented: $showingShortcuts) {
            ShortcutsHelpView(colors: colors)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcuts)) { _ in
            showingShortcuts = true
        }
        #else
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                content(for: tab)
                    .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        #endif
    }
    
    @ViewBuilder
    func content(for tab: Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView { filter in
                invoiceBrowsingState.searchText = ""
                switch filter {
                case .all, .outstanding: invoiceBrowsingState.selectedStatus = nil
                case .collectedMonth, .collectedYear: invoiceBrowsingState.selectedStatus = .paid
                case .overdue: invoiceBrowsingState.selectedStatus = .overdue
                }
                invoiceBrowsingState.onlyOutstanding = filter == .outstanding
                invoiceBrowsingState.paidPeriod = filter == .collectedMonth ? .month : filter == .collectedYear ? .year : nil
                selectedTab = .invoices
            }
        case .invoices: InvoiceListView(browsingState: $invoiceBrowsingState)
        case .clients: ClientListView(searchText: $clientSearchText)
        case .settings: SettingsView()
        }
    }
}

// Notification names are now in MiraApp.swift

// MARK: - Shortcuts Help View

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) var dismiss
    let colors: ThemeColors
    
    let shortcuts: [(category: String, items: [(keys: String, action: String)])] = [
        ("Navigation", [
            ("⌘ 1", "Dashboard"),
            ("⌘ 2", "Invoices"),
            ("⌘ 3", "Clients"),
            ("⌘ ,", "Settings")
        ]),
        ("Actions", [
            ("⌘ N", "New Invoice"),
            ("⌘ ⇧ N", "New Client"),
            ("⌘ K", "Show Shortcuts")
        ])
    ]
    
    var body: some View {
        NavigationStack {
            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(shortcuts, id: \.category) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.category)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.subtext)
                            
                            VStack(spacing: 8) {
                                ForEach(section.items, id: \.action) { item in
                                    HStack {
                                        Text(item.action)
                                            .font(.system(size: 14))
                                            .foregroundColor(colors.text)
                                        Spacer()
                                        Text(item.keys)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(colors.surface1)
                                            .foregroundColor(colors.text)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .padding(16)
                            .background(colors.surface0)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 360, height: 380)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AppState())
    }
}
