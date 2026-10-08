import SwiftUI
import SwiftData

enum DashboardInvoiceFilter { case all, collectedMonth, collectedYear, outstanding, overdue }

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]
    @State private var showingNewInvoice = false
    @State private var selectedInvoice: Invoice?
    @State private var selectedClient: Client?
    var onBrowseInvoices: (DashboardInvoiceFilter) -> Void = { _ in }

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }
    private var baseCurrency: Currency {
        usesSwiftData ? sdProfiles.first?.defaultCurrency ?? .eur : appState.companyProfile?.defaultCurrency ?? .eur
    }
    private var summaries: [InvoiceSummary] {
        let exempt = usesSwiftData ? sdProfiles.first?.isVatExempt ?? false : appState.companyProfile?.isVatExempt ?? false
        if usesSwiftData { return sdInvoices.map { InvoiceSummary($0, isVatExempt: exempt) } }
        let clients = Dictionary(appState.clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return appState.invoices.map { InvoiceSummary($0, client: clients[$0.clientId], isVatExempt: exempt) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let invoices = summaries
            let metrics = DashboardMetrics(invoices: invoices, baseCurrency: baseCurrency, now: timeline.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(greeting).font(.subheadline).foregroundStyle(colors.subtext)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { metricCards(metrics) }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) { metricCards(metrics) }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            revenueSection(metrics).frame(minWidth: 330)
                            topClientsSection(metrics).frame(width: 240)
                        }
                        VStack(spacing: 20) { revenueSection(metrics); topClientsSection(metrics) }
                    }
                    recentSection(invoices, now: timeline.date)
                }
                .padding(24)
            }
            .background(colors.base)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem {
                Button("New Invoice", systemImage: "plus") { showingNewInvoice = true }
                    .miraPrimaryAction().help("New Invoice (⌘N)")
            }
        }
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailView(invoice: invoice).environmentObject(appState).environment(\.themeColors, colors)
        }
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client).environmentObject(appState).environment(\.themeColors, colors)
        }
    }

    @ViewBuilder
    private func metricCards(_ metrics: DashboardMetrics) -> some View {
        metricCard("Collected This Month", totals: metrics.month, icon: "calendar", filter: .collectedMonth)
        metricCard("Collected This Year", totals: metrics.year, icon: "chart.line.uptrend.xyaxis", filter: .collectedYear)
        metricCard("Outstanding", totals: metrics.outstanding, icon: "clock", filter: .outstanding)
        if metrics.overdue.count > 0 {
            metricCard("Overdue", totals: metrics.overdue, icon: "exclamationmark.triangle", filter: .overdue, valueColor: .red)
        }
    }

    private func metricCard(_ title: String, totals: InvoiceTotals, icon: String, filter: DashboardInvoiceFilter, valueColor: Color? = nil) -> some View {
        Button { onBrowseInvoices(filter) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(.system(size: 12)).foregroundStyle(colors.subtext)
                Text(MiraFormat.currency(totals.baseAmount, baseCurrency))
                    .font(.system(size: 24, weight: .semibold)).monospacedDigit().foregroundStyle(valueColor ?? colors.text)
                Text("\(totals.count) \(totals.count == 1 ? "invoice" : "invoices")").font(.caption).foregroundStyle(colors.subtext)
                if let excluded = totals.exclusionDescription {
                    Text(excluded).font(.caption).foregroundStyle(colors.subtext).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18).frame(minWidth: 155, maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(colors.surface0, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).help("View \(title.lowercased()) invoices")
        .accessibilityElement(children: .combine)
    }

    private func revenueSection(_ metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Collected Revenue · \(baseCurrency.rawValue)").font(.subheadline.weight(.medium)).foregroundStyle(colors.text)
            Text("Last 6 months · by payment date").font(.caption).foregroundStyle(colors.subtext)
            if metrics.revenue.allSatisfy({ $0.amount == 0 }) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar").font(.title)
                    Text("No collected revenue in this period")
                    Text("Payments appear here after you mark an invoice as paid.").font(.caption)
                }
                .foregroundStyle(colors.subtext).frame(maxWidth: .infinity, minHeight: 160)
                .multilineTextAlignment(.center)
            } else {
                RevenueChart(data: metrics.revenue, currency: baseCurrency, colors: colors).frame(height: 170)
            }
            if let excluded = metrics.revenueExclusions.exclusionDescription {
                Text(excluded).font(.caption).foregroundStyle(colors.subtext)
            }
            if metrics.missingPaymentDates > 0 {
                Text("\(metrics.missingPaymentDates) paid invoices have no payment date and are excluded from period totals.")
                    .font(.caption).foregroundStyle(colors.subtext)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface0, in: RoundedRectangle(cornerRadius: 12))
    }

    private func topClientsSection(_ metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Clients").font(.subheadline.weight(.medium)).foregroundStyle(colors.text)
            Text("Collected this year").font(.caption).foregroundStyle(colors.subtext)
            if metrics.topClients.isEmpty {
                Text("Your clients appear here after their first payment.")
                    .font(.caption).foregroundStyle(colors.subtext)
                    .frame(maxWidth: .infinity, minHeight: 120).multilineTextAlignment(.center)
            } else {
                ForEach(metrics.topClients.prefix(4), id: \.id) { item in
                    Button {
                        selectedClient = usesSwiftData ? sdClients.first { $0.id == item.id }?.toLegacy() : appState.clients.first { $0.id == item.id }
                    } label: {
                        HStack {
                            Text(item.name).lineLimit(1)
                            Spacer()
                            Text(MiraFormat.currency(item.total, baseCurrency)).monospacedDigit()
                        }
                        .font(.subheadline).foregroundStyle(colors.text)
                    }
                    .buttonStyle(.plain).help("Open \(item.name)")
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface0, in: RoundedRectangle(cornerRadius: 12))
    }

    private func recentSection(_ invoices: [InvoiceSummary], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Invoices").font(.subheadline.weight(.medium)).foregroundStyle(colors.text)
                Spacer()
                if !invoices.isEmpty {
                    Button("View All", systemImage: "arrow.right") { onBrowseInvoices(.all) }.buttonStyle(.plain).foregroundStyle(colors.accent)
                }
            }
            if invoices.isEmpty {
                ContentUnavailableView {
                    Label("No invoices yet", systemImage: "doc.text")
                } description: { Text("Create your first invoice to start tracking your work.") }
                actions: { Button("Create your first invoice") { showingNewInvoice = true } }
            } else {
                let recent = invoices.sorted { $0.createdAt > $1.createdAt }.prefix(5)
                VStack(spacing: 0) {
                    ForEach(recent) { invoice in
                        Button { openInvoice(invoice.id) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(invoice.invoiceNumber).fontWeight(.medium)
                                    Text(invoice.clientName).font(.caption).foregroundStyle(colors.subtext)
                                }
                                Spacer()
                                Text(MiraFormat.currency(invoice.amount, invoice.currency)).monospacedDigit()
                                StatusBadge(status: invoice.effectiveStatus(at: now)).frame(width: 80)
                            }
                            .foregroundStyle(colors.text).padding(16).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help("Open invoice \(invoice.invoiceNumber)")
                        if invoice.id != recent.last?.id { Divider() }
                    }
                }
                .background(colors.surface0, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func openInvoice(_ id: UUID) {
        selectedInvoice = usesSwiftData ? sdInvoices.first { $0.id == id }?.toLegacy() : appState.invoices.first { $0.id == id }
    }
    private var greeting: String {
        let owner = usesSwiftData ? sdProfiles.first?.ownerName : appState.companyProfile?.ownerName
        let name = owner?.split(separator: " ").first.map(String.init) ?? ""
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return name.isEmpty ? prefix : "\(prefix), \(name)"
    }
}

struct RevenueChart: View {
    let data: [(month: String, amount: Double)]
    let currency: Currency
    let colors: ThemeColors
    var maxAmount: Double { max(data.map(\.amount).max() ?? 1, 1) }
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 8) {
                    Text(MiraFormat.currency(item.amount, currency)).font(.caption2).foregroundStyle(colors.subtext)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    RoundedRectangle(cornerRadius: 4).fill(colors.accent)
                        .frame(height: max(2, CGFloat(item.amount / maxAmount) * 115))
                    Text(item.month).font(.caption2).foregroundStyle(colors.subtext)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.month): \(MiraFormat.currency(item.amount, currency)) collected")
            }
        }
    }
}
