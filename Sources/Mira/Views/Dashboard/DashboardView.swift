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
        allInvoices.filter { $0.effectiveStatus == .overdue }
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
            // Bucket by the month the money came in, matching "came in this month" in the hero.
            let paid = allInvoices.filter { $0.status == .paid && calendar.isDate($0.paidAt ?? $0.issueDate, equalTo: date, toGranularity: .month) }
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
                firstRun
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
        let yearOverdue = totalFor(thisYearInvoices.filter { $0.effectiveStatus == .overdue })
        let yearOpen = totalFor(thisYearInvoices.filter { $0.effectiveStatus == .sent })
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
        let overdueText = Text("\(overdue) overdue").foregroundStyle(.red)
        return Text("\(base), \(overdueText)")
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
        let months = monthlyRevenue
        let total = months.reduce(0) { $0 + $1.amount }
        let activeMonths = months.filter { $0.amount > 0 }.count
        return VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Revenue, last 6 months") {
                if total > 0 {
                    HStack(spacing: Spacing.l) {
                        chartStat("Total", Money.string(total, baseCurrency))
                        chartStat("Avg. per month", Money.string(total / Double(max(activeMonths, 1)), baseCurrency))
                    }
                }
            }
            RevenueChart(data: months, currency: baseCurrency, accent: colors.accent)
                .frame(height: 200)
                .padding(Spacing.l)
                .groupedSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Top clients

    private var topClientsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Top clients this year")
            if topClients.isEmpty {
                topClientsPlaceholder
            } else {
                let shown = Array(topClients.prefix(5))
                let top = shown.first?.total ?? 1
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.client.id) { index, item in
                        HoverRow {
                            nav.reveal(clientID: item.client.id)
                        } content: {
                            HStack(spacing: Spacing.m) {
                                ClientAvatar(name: item.client.name, size: 28)
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(item.client.name)
                                        .lineLimit(1)
                                    // Share bar: how this client compares to the top one.
                                    GeometryReader { geo in
                                        Capsule()
                                            .fill(colors.accent.opacity(0.8))
                                            .frame(width: max(4, geo.size.width * item.total / max(top, 1)))
                                    }
                                    .frame(height: 3)
                                    .background(Capsule().fill(.quaternary.opacity(0.6)))
                                }
                                Spacer(minLength: Spacing.m)
                                MoneyText(item.total, baseCurrency, font: .callout, weight: .medium)
                            }
                            .font(.callout)
                        }
                        .accessibilityLabel("\(item.client.name), \(Money.string(item.total, baseCurrency)). Show client")
                        if index < shown.count - 1 {
                            Divider().padding(.horizontal, Spacing.s)
                        }
                    }
                }
                .padding(Spacing.xs)
                .groupedSurface()
            }
        }
    }

    /// Three ghost rows in the same layout as real ones, faded, plus a line
    /// saying what fills them. Keeps the column looking designed, not broken.
    private var topClientsPlaceholder: some View {
        let widths: [CGFloat] = [96, 72, 84]
        let shares: [CGFloat] = [1.0, 0.7, 0.45]
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: Spacing.m) {
                    Circle()
                        .fill(colors.accent.opacity(0.14))
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: widths[index], height: 9)
                        GeometryReader { geo in
                            Capsule()
                                .fill(colors.accent.opacity(0.35))
                                .frame(width: geo.size.width * shares[index])
                        }
                        .frame(height: 3)
                        .background(Capsule().fill(.quaternary.opacity(0.6)))
                    }
                    Spacer(minLength: Spacing.m)
                    Capsule()
                        .fill(.quaternary)
                        .frame(width: 48, height: 9)
                }
                .padding(.vertical, Spacing.m)
                .padding(.horizontal, Spacing.s)
                if index < 2 {
                    Divider().padding(.horizontal, Spacing.s)
                }
            }
            Text("Your best-paying clients rank here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
        }
        .padding(Spacing.xs)
        .groupedSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Top clients. Your best-paying clients rank here once invoices are paid.")
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
                    status: invoice.effectiveStatus,
                    clientName: clients[invoice.clientId]?.name ?? "No client",
                    amount: isVatExempt ? invoice.subtotal : invoice.total
                ) {
                    nav.reveal(invoiceID: invoice.id)
                }
                if index < invoices.count - 1 {
                    Divider().padding(.horizontal, Spacing.s)
                }
            }
        }
        .padding(Spacing.xs)
        .groupedSurface()
    }

    // MARK: First run

    /// Shown until the first invoice exists. Keeps the page's real shape so
    /// the user sees what fills in, and walks them through the first steps.
    private var firstRun: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                firstRunHero
                gettingStarted
                HStack(alignment: .top, spacing: Spacing.xxl) {
                    revenueSection
                    topClientsSection
                        .frame(width: 280)
                }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(Spacing.page)
        }
    }

    private var firstRunHero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(allClients.isEmpty ? "Let's get you paid" : "Ready for your first invoice")
                .font(.system(size: 44, weight: .semibold))
            Text("Once you've sent an invoice, this page shows what's owed, what's been paid and who your best clients are.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 620, alignment: .leading)
        }
    }

    private struct SetupStep: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let symbol: String
        let done: Bool
        let action: (() -> Void)?
    }

    private var steps: [SetupStep] {
        let hasProfile = profile != nil
        let hasClient = !allClients.isEmpty
        return [
            SetupStep(id: 1, title: "Set up your business", detail: "Name, address, tax and bank details go on every invoice.",
                 symbol: "building.2", done: hasProfile, action: nil),
            SetupStep(id: 2, title: "Add your first client", detail: "Who you're billing. You only type their details once.",
                 symbol: "person.badge.plus", done: hasClient, action: { nav.sheet = .newClient }),
            SetupStep(id: 3, title: "Create an invoice", detail: "Pick the client, add line items, and watch the PDF build itself.",
                 symbol: "doc.badge.plus", done: false, action: { nav.sheet = .newInvoice(clientID: allClients.first?.id) }),
            SetupStep(id: 4, title: "Send it and mark it paid", detail: "Export the PDF, then record the payment when it lands.",
                 symbol: "paperplane", done: false, action: nil),
        ]
    }

    private var gettingStarted: some View {
        let steps = steps
        let doneCount = steps.filter(\.done).count
        let next = steps.first { !$0.done }
        return VStack(alignment: .leading, spacing: Spacing.l) {
            SectionTitle("Getting started") {
                Text("\(doneCount) of \(steps.count) done")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            VStack(spacing: 0) {
                ForEach(steps) { (step: SetupStep) in
                    let isNext = step.id == next?.id
                    HStack(spacing: Spacing.l) {
                        ZStack {
                            Circle()
                                .fill(step.done ? Color.green.opacity(0.16) : (isNext ? colors.accent.opacity(0.16) : Color.secondary.opacity(0.1)))
                            Image(systemName: step.done ? "checkmark" : step.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(step.done ? Color.green : (isNext ? colors.accent : Color.secondary))
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .fontWeight(.medium)
                                .strikethrough(step.done, color: .secondary)
                                .foregroundStyle(step.done ? .secondary : .primary)
                            Text(step.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Spacing.m)

                        if step.done {
                            Text("Done")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else if let action = step.action {
                            let label = step.title.hasPrefix("Add") ? "Add client" : "New invoice"
                            if isNext {
                                Button(label, action: action).buttonStyle(.borderedProminent)
                            } else {
                                Button(label, action: action).buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, Spacing.m)
                    .padding(.horizontal, Spacing.l)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(step.title). \(step.done ? "Done" : step.detail)")
                    if step.id != steps.last?.id {
                        Divider().padding(.horizontal, Spacing.l)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
            .groupedSurface()
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

    private var isEmpty: Bool { data.allSatisfy { $0.amount <= 0 } }

    /// Illustrative shape shown faded while there is no revenue yet, so the
    /// card reads as a chart rather than an empty box. Unlabeled on purpose.
    private static let sampleShape: [Double] = [0.35, 0.6, 0.45, 0.8, 0.55, 0.7]

    private var plotted: [DashboardView.MonthRevenue] {
        guard isEmpty else { return data }
        return data.enumerated().map { index, month in
            DashboardView.MonthRevenue(id: month.id, label: month.label, amount: Self.sampleShape[index % Self.sampleShape.count] * 1000)
        }
    }

    /// Fixed upper bound so the axis, gridlines and labels render even when
    /// every month is zero, and bars never touch the top edge.
    private var yMax: Double {
        let peak = data.map(\.amount).max() ?? 0
        return peak > 0 ? peak * 1.2 : 1000
    }

    var body: some View {
        Chart(plotted) { month in
            BarMark(
                x: .value("Month", month.id, unit: .month),
                y: .value("Revenue", month.amount),
                width: .ratio(0.55)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: isEmpty ? [accent.opacity(0.28), accent.opacity(0.08)] : [accent, accent.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .opacity(selected == nil || selected?.id == month.id ? 1 : 0.35)
            .cornerRadius(5)

            if !isEmpty, let selected, selected.id == month.id {
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
        .chartYScale(domain: 0...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(.quaternary)
                if !isEmpty {
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Money.compact(amount, currency))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                Rectangle().fill(.quaternary).frame(height: 1)
            }
        }
        .overlay {
            if isEmpty {
                VStack(spacing: Spacing.xs) {
                    Text("Sample")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                    Text("Paid revenue by month appears here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .allowsHitTesting(false)
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
