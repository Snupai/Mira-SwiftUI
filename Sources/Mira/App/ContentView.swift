import SwiftUI
import SwiftData

/// Root of the main window. Decides between onboarding and the main split
/// view. The theme is installed one level up by `RootView` so the migration
/// screen is themed too.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @Query private var profiles: [SDCompanyProfile]

    /// Setup is complete once onboarding has been finished and a company
    /// profile exists. Deliberately not gated on the profile's encrypted fields
    /// (IBAN etc.): if those can't be decrypted — for example in a build signed
    /// with a different identity — the user must still be able to reach the app.
    private var isSetupComplete: Bool {
        guard appState.hasCompletedOnboarding else { return false }
        return profiles.first != nil || appState.companyProfile != nil
    }

    var body: some View {
        Group {
            if isSetupComplete {
                MainView()
            } else {
                OnboardingContainerView()
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

// MARK: - Main window

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) private var colors
    @Environment(\.openSettings) private var openSettings
    @State private var nav = NavigationModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @Query private var sdInvoices: [SDInvoice]

    private var invoiceStatusCounts: [InvoiceStatus: Int] {
        let invoices: [Invoice] = MigrationService.shared.useSwiftData
            ? sdInvoices.map { $0.toLegacy() }
            : appState.invoices
        var counts: [InvoiceStatus: Int] = [:]
        for invoice in invoices {
            // Treat sent-but-past-due as overdue in the sidebar so the count is honest.
            let status: InvoiceStatus = (invoice.status == .sent && invoice.isOverdue) ? .overdue : invoice.status
            counts[status, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(statusCounts: invoiceStatusCounts)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 300)
        } detail: {
            detail
                .background(contentBackground)
        }
        .environment(nav)
        .sheet(item: $nav.sheet) { sheet in
            sheetContent(sheet)
                .environmentObject(appState)
                .environment(nav)
                .themed()
        }
        .onAppear {
            if NavigationModel.wantsFirstInvoice {
                NavigationModel.wantsFirstInvoice = false
                nav.section = .invoices
                nav.sheet = .newInvoice(clientID: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newInvoice)) { _ in
            nav.sheet = .newInvoice(clientID: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newClient)) { _ in
            nav.sheet = .newClient
        }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcuts)) { _ in
            nav.sheet = .shortcuts
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            guard let target = notification.object as? String else { return }
            switch target {
            case "dashboard": nav.section = .overview
            case "invoices": nav.showInvoices()
            case "clients": nav.section = .clients
            case "settings": openSettings()
            default: break
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch nav.section {
        case .overview: DashboardView()
        case .invoices: InvoicesView()
        case .clients: ClientListView()
        }
    }

    /// System themes leave the window background alone so glass chrome shows
    /// the desktop through it; custom palettes paint their base color.
    @ViewBuilder
    private var contentBackground: some View {
        if colors.isSystem {
            Color.clear
        } else {
            colors.base.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: MainSheet) -> some View {
        switch sheet {
        case .newInvoice(let clientID):
            InvoiceEditorView(invoice: nil, preselectedClientID: clientID)
        case .editInvoice(let invoice):
            InvoiceEditorView(invoice: invoice)
        case .newClient:
            ClientEditorView(client: nil)
        case .editClient(let client):
            ClientEditorView(client: client)
        case .shortcuts:
            ShortcutsHelpView()
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors
    let statusCounts: [InvoiceStatus: Int]

    enum Item: Hashable {
        case section(MainSection)
        case status(InvoiceStatus)
    }

    @State private var selection: Item? = .section(.overview)

    private let shownStatuses: [InvoiceStatus] = [.draft, .sent, .overdue, .paid]

    var body: some View {
        List(selection: $selection) {
            ForEach(MainSection.allCases) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(Item.section(section))
            }

            Section("By status") {
                ForEach(shownStatuses, id: \.self) { status in
                    Label {
                        Text(status.rawValue)
                    } icon: {
                        Image(systemName: status.symbol)
                            .foregroundStyle(status.tint(accent: colors.accent))
                    }
                    .badge(statusCounts[status, default: 0])
                    .tag(Item.status(status))
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .keyboardShortcut(",", modifiers: .command)
        }
        .onChange(of: selection) { _, newValue in
            switch newValue {
            case .section(let section):
                nav.section = section
                if section == .invoices { nav.invoiceFilter = nil }
            case .status(let status):
                nav.showInvoices(filter: status)
            case nil:
                break
            }
        }
        .onChange(of: nav.section) { _, section in
            syncSelection(section: section, filter: nav.invoiceFilter)
        }
        .onChange(of: nav.invoiceFilter) { _, filter in
            syncSelection(section: nav.section, filter: filter)
        }
    }

    private func syncSelection(section: MainSection, filter: InvoiceStatus?) {
        let target: Item
        if section == .invoices, let filter, shownStatuses.contains(filter) {
            target = .status(filter)
        } else {
            target = .section(section)
        }
        if selection != target { selection = target }
    }
}

// MARK: - Keyboard shortcuts sheet

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let groups: [(title: String, items: [(keys: String, action: String)])] = [
        ("Navigate", [
            ("⌘ 1", "Overview"),
            ("⌘ 2", "Invoices"),
            ("⌘ 3", "Clients"),
            ("⌘ ,", "Settings"),
        ]),
        ("Create", [
            ("⌘ N", "New invoice"),
            ("⌘ ⇧ N", "New client"),
        ]),
        ("Help", [
            ("⌘ K", "Keyboard shortcuts"),
        ]),
    ]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items, id: \.action) { item in
                            LabeledContent(item.action) {
                                Text(item.keys)
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .themedGroupedForm()
            .navigationTitle("Keyboard shortcuts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 380, height: 420)
    }
}

#Preview {
    ContentView().environmentObject(AppState()).themed()
}
