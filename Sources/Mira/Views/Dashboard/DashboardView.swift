import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData queries
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]
    
    @State private var showingNewInvoice = false
    
    // Use SwiftData if migrated or no legacy data exists
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    private var allInvoices: [Invoice] {
        if usesSwiftData && !sdInvoices.isEmpty {
            return sdInvoices.map { $0.toLegacy() }
        }
        return appState.invoices
    }
    
    private var allClients: [Client] {
        if usesSwiftData && !sdClients.isEmpty {
            return sdClients.map { $0.toLegacy() }
        }
        return appState.clients
    }
    
    var isVatExempt: Bool { 
        if let profile = sdProfiles.first {
            return profile.isVatExempt
        }
        return appState.companyProfile?.isVatExempt ?? false 
    }
    
    // Stats calculations
    var thisMonthInvoices: [Invoice] {
        let now = Date()
        let calendar = Calendar.current
        return allInvoices.filter {
            calendar.isDate($0.issueDate, equalTo: now, toGranularity: .month)
        }
    }
    
    var thisYearInvoices: [Invoice] {
        let now = Date()
        let calendar = Calendar.current
        return allInvoices.filter {
            calendar.isDate($0.issueDate, equalTo: now, toGranularity: .year)
        }
    }
    
    var outstandingInvoices: [Invoice] {
        allInvoices.filter { $0.status == .sent || $0.status == .overdue }
    }
    
    var overdueInvoices: [Invoice] {
        allInvoices.filter { $0.status == .overdue || ($0.status == .sent && $0.isOverdue) }
    }
    
    var baseCurrency: Currency { 
        if let profile = sdProfiles.first {
            return profile.defaultCurrency
        }
        return appState.companyProfile?.defaultCurrency ?? .eur 
    }
    
    func totalFor(_ invoices: [Invoice]) -> Double {
        invoices.reduce(0) { total, invoice in
            let invoiceAmount = isVatExempt ? invoice.subtotal : invoice.total
            
            // For paid invoices with saved conversion, use the base currency amount
            if invoice.status == .paid, let baseAmount = invoice.paidAmountInBaseCurrency {
                return total + baseAmount
            }
            
            // For invoices in the same currency as base, use the amount directly
            if invoice.currency == baseCurrency {
                return total + invoiceAmount
            }
            
            // For unpaid invoices in different currencies, we can't accurately convert
            // Just skip them in the total (they'll be counted when paid with actual rate)
            return total
        }
    }
    
    // Monthly data for chart (last 6 months)
    var monthlyRevenue: [(month: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        return (0..<6).reversed().map { monthsAgo in
            let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now)!
            let monthInvoices = allInvoices.filter { inv in
                inv.status == .paid && calendar.isDate(inv.issueDate, equalTo: date, toGranularity: .month)
            }
            return (formatter.string(from: date), totalFor(monthInvoices))
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(colors.text)
                        Text(greeting)
                            .font(.system(size: 14))
                            .foregroundColor(colors.subtext)
                    }
                    Spacer()
                    Button(action: { showingNewInvoice = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New Invoice")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(colors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                // Stats Row
                HStack(spacing: 16) {
                    StatCard(
                        title: "This Month",
                        value: formatCurrency(totalFor(thisMonthInvoices.filter { $0.status == .paid })),
                        subtitle: "\(thisMonthInvoices.count) invoices",
                        icon: "calendar",
                        colors: colors
                    )
                    StatCard(
                        title: "This Year",
                        value: formatCurrency(totalFor(thisYearInvoices.filter { $0.status == .paid })),
                        subtitle: "\(thisYearInvoices.filter { $0.status == .paid }.count) paid",
                        icon: "chart.line.uptrend.xyaxis",
                        colors: colors
                    )
                    StatCard(
                        title: "Outstanding",
                        value: formatCurrency(totalFor(outstandingInvoices)),
                        subtitle: "\(outstandingInvoices.count) pending",
                        icon: "clock",
                        colors: colors,
                        valueColor: outstandingInvoices.isEmpty ? nil : colors.accent
                    )
                    if !overdueInvoices.isEmpty {
                        StatCard(
                            title: "Overdue",
                            value: formatCurrency(totalFor(overdueInvoices)),
                            subtitle: "\(overdueInvoices.count) need attention",
                            icon: "exclamationmark.triangle",
                            colors: colors,
                            valueColor: .red
                        )
                    }
                }
                
                // Revenue Chart & Recent
                HStack(alignment: .top, spacing: 20) {
                    // Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Revenue (Last 6 Months)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.subtext)
                        
                        RevenueChart(data: monthlyRevenue, colors: colors)
                            .frame(height: 160)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(colors.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Top Clients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Top Clients")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.subtext)
                        
                        if topClients.isEmpty {
                            Text("No invoices yet")
                                .font(.system(size: 13))
                                .foregroundColor(colors.subtext)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(topClients.prefix(4), id: \.client.id) { item in
                                    HStack {
                                        Text(item.client.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(colors.text)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatCurrency(item.total))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(colors.accent)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(width: 240)
                    .background(colors.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Recent Invoices
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Invoices")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.subtext)
                        Spacer()
                        if allInvoices.count > 5 {
                            Text("View All →")
                                .font(.system(size: 12))
                                .foregroundColor(colors.accent)
                        }
                    }
                    
                    if allInvoices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundColor(colors.subtext)
                            Text("No invoices yet")
                                .font(.system(size: 14))
                                .foregroundColor(colors.subtext)
                            Button("Create your first invoice") { showingNewInvoice = true }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.accent)
                                .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(colors.surface0)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(allInvoices.sorted { $0.createdAt > $1.createdAt }.prefix(5).enumerated()), id: \.element.id) { index, invoice in
                                InvoiceRowDashboard(
                                    invoice: invoice,
                                    client: allClients.first { $0.id == invoice.clientId },
                                    colors: colors,
                                    isVatExempt: isVatExempt,
                                    baseCurrency: baseCurrency
                                )
                                if index < 4 {
                                    Divider().background(colors.surface1)
                                }
                            }
                        }
                        .background(colors.surface0)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(32)
        }
        .background(colors.base)
        .sheet(isPresented: $showingNewInvoice) {
            InvoiceEditorView(invoice: nil).environmentObject(appState).environment(\.themeColors, colors)
        }
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.companyProfile?.ownerName.components(separatedBy: " ").first ?? ""
        let prefix = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return name.isEmpty ? prefix : "\(prefix), \(name)"
    }
    
    var topClients: [(client: Client, total: Double)] {
        var clientTotals: [UUID: Double] = [:]
        for invoice in thisYearInvoices.filter({ $0.status == .paid }) {
            let invoiceAmount = isVatExempt ? invoice.subtotal : invoice.total
            
            // Use base currency amount if available, otherwise use direct amount if same currency
            if let baseAmount = invoice.paidAmountInBaseCurrency {
                clientTotals[invoice.clientId, default: 0] += baseAmount
            } else if invoice.currency == baseCurrency {
                clientTotals[invoice.clientId, default: 0] += invoiceAmount
            }
            // Skip invoices in different currencies without conversion data
        }
        return clientTotals.compactMap { id, total in
            guard let client = allClients.first(where: { $0.id == id }) else { return nil }
            return (client, total)
        }.sorted { $0.total > $1.total }
    }
    
    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = appState.companyProfile?.defaultCurrency.rawValue ?? "EUR"
        return f.string(from: NSNumber(value: value)) ?? "€0"
    }
}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let colors: ThemeColors
    var valueColor: Color? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(colors.subtext)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.subtext)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(valueColor ?? colors.text)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(colors.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(colors.surface0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RevenueChart: View {
    let data: [(month: String, amount: Double)]
    let colors: ThemeColors
    
    var maxAmount: Double { max(data.map(\.amount).max() ?? 1, 1) }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 8) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.accent.opacity(item.amount > 0 ? 1 : 0.3))
                        .frame(width: 32, height: max(4, CGFloat(item.amount / maxAmount) * 120))
                    Text(item.month)
                        .font(.system(size: 10))
                        .foregroundColor(colors.subtext)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct InvoiceRowDashboard: View {
    let invoice: Invoice
    let client: Client?
    let colors: ThemeColors
    let isVatExempt: Bool
    let baseCurrency: Currency
    
    var displayTotal: Double { isVatExempt ? invoice.subtotal : invoice.total }
    
    // Amount to display in base currency
    var baseCurrencyAmount: Double? {
        if invoice.status == .paid, let baseAmount = invoice.paidAmountInBaseCurrency {
            return baseAmount
        } else if invoice.currency == baseCurrency {
            return displayTotal
        }
        return nil // Can't convert unpaid foreign currency invoices
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.text)
                Text(client?.name ?? "—")
                    .font(.system(size: 13))
                    .foregroundColor(colors.subtext)
            }
            
            Spacer()
            
            Text(formatDate(invoice.issueDate))
                .font(.system(size: 12))
                .foregroundColor(colors.subtext)
                .frame(width: 80)
            
            // Show base currency amount (or original with indicator if can't convert)
            VStack(alignment: .trailing, spacing: 2) {
                if let baseAmount = baseCurrencyAmount {
                    Text(formatCurrency(baseAmount, currency: baseCurrency))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colors.text)
                } else {
                    Text(formatCurrency(displayTotal, currency: invoice.currency))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colors.text)
                    Text("(\(invoice.currency.rawValue))")
                        .font(.system(size: 10))
                        .foregroundColor(colors.subtext)
                }
            }
            .frame(width: 100, alignment: .trailing)
            
            Text(invoice.status.rawValue)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
                .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    var statusColor: Color {
        switch invoice.status {
        case .paid: return .green
        case .overdue: return .red
        case .sent: return colors.accent
        default: return colors.subtext
        }
    }
    
    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: d)
    }
    
    func formatCurrency(_ value: Double, currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView().environmentObject(AppState())
    }
}
