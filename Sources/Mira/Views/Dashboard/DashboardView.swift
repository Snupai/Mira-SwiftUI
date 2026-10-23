import SwiftUI
import SwiftData
import Charts

/// Overview: what is owed to you right now, how the year is going, and the
/// invoices that need a hand. Flat content, one large number, no tile grid.
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(NavigationModel.self) private var nav
    @Environment(\.themeColors) private var colors

    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]

    // MARK: Data

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    private var allInvoices: [Invoice] {
        usesSwiftData ? sdInvoices.map { $0.toLegacy() } : appState.invoices
    }

    private var allClients: [Client] {
        usesSwiftData ? sdClients.map { $0.toLegacy() } : appState.clients
    }

    private var clientsByID: [UUID: Client] {
        Dictionary(allClients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var profile: CompanyProfile? {
        usesSwiftData ? sdProfiles.first?.toLegacy() : appState.companyProfile
    }

    private var isVatExempt: Bool { profile?.isVatExempt ?? false }
    private var baseCurrency: Currency { profile?.defaultCurrency ?? .eur }

    private func effectiveStatus(_ invoice: Invoice) -> InvoiceStatus {
        (invoice.status == .sent && invoice.isOverdue) ? .overdue : invoice.status
    }

    /// Sums invoices in the base currency. Paid invoices use the recorded
    /// converted amount; unpaid foreign-currency invoices are skipped because
    /// there is no honest rate for them yet.
    private func totalFor(_ invoices: [Invoice]) -> Double {
        invoices.reduce(0) { total, invoice in
            let amount = isVatExempt ? invoice.subtotal : invoice.total
            if invoice.status == .paid, let base = invoice.paidAmountInBaseCurrency {
                return total + base
            }
            if invoice.currency == baseCurrency {
                return total + amount
            }
            return total
        }
    }

    private var thisYearInvoices: [Invoice] {
        let calendar = Calendar.current
        return allInvoices.filter { calendar.isDate($0.issueDate, equalTo: Date(), toGranularity: .year) }
    }

    private var thisMonthPaid: [Invoice] {
        let calendar = Calendar.current
        return allInvoices.filter { $0.status == .paid && calendar.isDate($0.paidAt ?? $0.issueDate, equalTo: Date(), toGranularity: .month) }
    }

    private var outstandingInvoices: [Invoice] {
        allInvoices.filter { $0.status == .sent || $0.status == .overdue }
    }

    private var overdueInvoices: [Invoice] {
        allInvoices.filter { effectiveStatus($0) == .overdue }
    }

    private var staleDrafts: [Invoice] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allInvoices.filter { $0.status == .draft && $0.createdAt < cutoff }
    }

    private var needsAttention: [Invoice] {
        (overdueInvoices + staleDrafts).sorted { $0.dueDate < $1.dueDate }
    }

    private var recentInvoices: [Invoice] {
        Array(allInvoices.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    fileprivate struct MonthRevenue: Identifiable {
        let id: Date
        let label: String
        let amount: Double
    }

    private var monthlyRevenue: [MonthRevenue] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().compactMap { monthsAgo in
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: Date()),
                  let start = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
            let paid = allInvoices.filter { $0.status == .paid && calendar.isDate($0.issueDate, equalTo: date, toGranularity: .month) }
            return MonthRevenue(id: start, label: formatter.string(from: date), amount: totalFor(paid))
        }
    }

    private var topClients: [(client: Client, total: Double)] {
        var totals: [UUID: Double] = [:]
        for invoice in thisYearInvoices where invoice.status == .paid {
            let amount = isVatExempt ? invoice.subtotal : invoice.total
            if let base = invoice.paidAmountInBaseCurrency {
                totals[invoice.clientId, default: 0] += base
            } else if invoice.currency == baseCurrency {
                totals[invoice.clientId, default: 0] += amount
            }
        }
        let clients = clientsByID
        return totals.compactMap { id, total in
            clients[id].map { ($0, total) }
        }
        .sorted { $0.total > $1.total }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let first = profile?.ownerName.split(separator: " ").first.map(String.init) ?? ""
        if first.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f.string(from: Date())
        }
        return "\(prefix), \(first)"
    }

    // MARK: Body

    var body: some View {
        Group {
            if allInvoices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xxl) {
                        hero
                        HStack(alignment: .top, spacing: Spacing.xxl) {
                            revenueSection
                            topClientsSection
                                .frame(width: 280)
                        }
                        if !needsAttention.isEmpty {
                            attentionSection
                        }
                        recentSection
                    }
                    .frame(maxWidth: 960, alignment: .leading)
                    .padding(Spacing.page)
                }
            }
        }
        .navigationTitle("Overview")
        .navigationSubtitle(greeting)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New invoice", systemImage: "plus") {
                    nav.sheet = .newInvoice(clientID: nil)
                }
                .help("New invoice (⌘N)")
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let outstandingTotal = totalFor(outstandingInvoices)
        let overdueCount = overdueInvoices.count
        let yearPaid = totalFor(thisYearInvoices.filter { $0.status == .paid })
        let yearOverdue = totalFor(thisYearInvoices.filter { effectiveStatus($0) == .overdue })
        let yearOpen = totalFor(thisYearInvoices.filter { effectiveStatus($0) == .sent })
        let yearTotal = yearPaid + yearOverdue + yearOpen

        return VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if outstandingInvoices.isEmpty {
                    Text("Nothing outstanding")
                        .font(.system(size: 44, weight: .semibold))
                    Text("Everything you've sent has been paid. \(Money.string(totalFor(thisMonthPaid), baseCurrency)) came in this month.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text(Money.string(outstandingTotal, baseCurrency))
                        .font(.system(size: 44, weight: .semibold))
                        .monospacedDigit()
                    outstandingSentence(count: outstandingInvoices.count, overdue: overdueCount)
                        .font(.title3)
                        .monospacedDigit()
                }
            }

            if yearTotal > 0 {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            segment(yearPaid / yearTotal, width: geo.size.width, color: .green)
                            segment(yearOpen / yearTotal, width: geo.size.width, color: colors.accent)
                            segment(yearOverdue / yearTotal, width: geo.size.width, color: .red)
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("This year: \(Money.string(yearPaid, baseCurrency)) paid, \(Money.string(yearOpen, baseCurrency)) outstanding, \(Money.string(yearOverdue, baseCurrency)) overdue")

                    HStack(spacing: Spacing.xl) {
                        legend("Paid", yearPaid, color: .green)
                        legend("Outstanding", yearOpen, color: colors.accent)
                        if yearOverdue > 0 {
                            legend("Overdue", yearOverdue, color: .red)
                        }
                        Spacer()
                        Text("This year")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func outstandingSentence(count: Int, overdue: Int) -> Text {
        let base = Text("Outstanding across \(count) \(count == 1 ? "invoice" : "invoices")")
            .foregroundStyle(.secondary)
        guard overdue > 0 else { return base }
        return base
            + Text(", ").foregroundStyle(.secondary)
            + Text("\(overdue) overdue").foregroundStyle(.red)
    }

    @ViewBuilder
    private func segment(_ fraction: Double, width: CGFloat, color: Color) -> some View {
        if fraction > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(2, width * fraction))
        }
    }

    private func legend(_ label: String, _ amount: Double, color: Color) -> some View {
        HStack(spacing: Spacing.s) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
            MoneyText(amount, baseCurrency, font: .callout, weight: .medium)
        }
        .font(.callout)
    }

    // MARK: Revenue chart

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Revenue, last 6 months")
            RevenueChart(data: monthlyRevenue, currency: baseCurrency, accent: colors.accent)
                .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Top clients

    private var topClientsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Top clients this year")
            if topClients.isEmpty {
                Text("No paid invoices yet this year.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(topClients.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.client.id) { index, item in
                        HoverRow {
                            nav.reveal(clientID: item.client.id)
                        } content: {
                            HStack(spacing: Spacing.m) {
                                ClientAvatar(name: item.client.name, size: 28)
                                Text(item.client.name)
                                    .lineLimit(1)
                                Spacer(minLength: Spacing.m)
                                MoneyText(item.total, baseCurrency, font: .callout, weight: .medium)
                            }
                            .font(.callout)
                        }
                        .accessibilityLabel("\(item.client.name), \(Money.string(item.total, baseCurrency)). Show client")
                        if index < shown.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: Attention and recent

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Needs attention")
            invoiceRows(needsAttention)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Recent invoices") {
                Button("Show all") { nav.showInvoices() }
                    .buttonStyle(.borderless)
            }
            invoiceRows(recentInvoices)
        }
    }

    private func invoiceRows(_ invoices: [Invoice]) -> some View {
        let clients = clientsByID
        return VStack(spacing: 0) {
            ForEach(Array(invoices.enumerated()), id: \.element.id) { index, invoice in
                InvoiceSummaryRow(
                    invoice: invoice,
                    status: effectiveStatus(invoice),
                    clientName: clients[invoice.clientId]?.name ?? "No client",
                    amount: isVatExempt ? invoice.subtotal : invoice.total
                ) {
                    nav.reveal(invoiceID: invoice.id)
                }
                if index < invoices.count - 1 {
                    Divider()
                }
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to show yet", systemImage: "chart.bar")
        } description: {
            Text("Your revenue, outstanding payments and recent invoices appear here once you've sent your first invoice.")
        } actions: {
            Button("New invoice") { nav.sheet = .newInvoice(clientID: nil) }
                .buttonStyle(.borderedProminent)
            Button("Add client") { nav.sheet = .newClient }
        }
    }
}

// MARK: - Chart

private struct RevenueChart: View {
    let data: [DashboardView.MonthRevenue]
    let currency: Currency
    let accent: Color
    @State private var selectedMonth: Date?

    private var selected: DashboardView.MonthRevenue? {
        guard let selectedMonth else { return nil }
        let calendar = Calendar.current
        return data.first { calendar.isDate($0.id, equalTo: selectedMonth, toGranularity: .month) }
    }

    var body: some View {
        Chart(data) { month in
            BarMark(
                x: .value("Month", month.id, unit: .month),
                y: .value("Revenue", month.amount)
            )
            .foregroundStyle(selected == nil || selected?.id == month.id ? accent : accent.opacity(0.35))
            .cornerRadius(4)

            if let selected, selected.id == month.id {
                RuleMark(x: .value("Month", selected.id, unit: .month))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: Spacing.xs) {
                        VStack(spacing: 2) {
                            Text(Money.string(selected.amount, currency))
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                            Text(selected.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
            }
        }
        .chartXSelection(value: $selectedMonth)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(Money.compact(amount, currency))
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityLabel("Paid revenue per month for the last six months")
    }
}

// MARK: - Row components

/// A plain row that lights up softly on hover and acts as a button.
private struct HoverRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.vertical, Spacing.m)
                .padding(.horizontal, Spacing.s)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(isHovered ? 0.5 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

private struct InvoiceSummaryRow: View {
    let invoice: Invoice
    let status: InvoiceStatus
    let clientName: String
    let amount: Double
    let action: () -> Void

    var body: some View {
        HoverRow(action: action) {
            HStack(spacing: Spacing.m) {
                StatusBadge(status: status)
                    .frame(width: 84, alignment: .leading)
                Text(invoice.invoiceNumber)
                    .fontWeight(.medium)
                    .monospacedDigit()
                Text(clientName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.m)
                if let relative = Dates.relativeDue(invoice.dueDate, status: status) {
                    Text(relative)
                        .font(.callout)
                        .foregroundStyle(status == .overdue ? Color.red : Color.secondary)
                } else if status == .draft {
                    Text("Draft since \(Dates.medium.string(from: invoice.createdAt))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                MoneyText(amount, invoice.currency, font: .callout, weight: .medium)
                    .frame(width: 110, alignment: .trailing)
            }
        }
        .accessibilityLabel("\(invoice.invoiceNumber), \(clientName), \(status.rawValue), \(Money.string(amount, invoice.currency)). Show invoice")
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environment(NavigationModel())
}
