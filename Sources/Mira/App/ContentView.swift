import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var appearance = AppAppearance.shared
    @Environment(\.colorScheme) var colorScheme
    
    var themeColors: ThemeColors {
        appearance.colors(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if appState.hasCompletedOnboarding && appState.companyProfile != nil {
                MainView()
            } else {
                OnboardingContainerView()
            }
        }
        .environment(\.themeColors, themeColors)
        .tint(themeColors.accent)
        .background(themeColors.base)
        .foregroundColor(themeColors.text)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @State private var selectedTab: Tab = .invoices
    @State private var showingNewInvoice = false
    @State private var showingNewClient = false
    
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
        HStack(spacing: 0) {
            // Custom sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    SidebarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        colors: colors,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 200)
            .background(colors.mantle)
            
            // Content
            content(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.base)
        }
        .background(colors.base)
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
        case .dashboard: DashboardView()
        case .invoices: InvoiceListView()
        case .clients: ClientListView()
        case .settings: SettingsView()
        }
    }
}

// Notification names for keyboard shortcuts
extension Notification.Name {
    static let newInvoice = Notification.Name("newInvoice")
    static let newClient = Notification.Name("newClient")
}

struct SidebarButton: View {
    let tab: MainView.Tab
    let isSelected: Bool
    let colors: ThemeColors
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 14))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? .white : colors.text)
            .background(isSelected ? colors.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AppState())
    }
}
