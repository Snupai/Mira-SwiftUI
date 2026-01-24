import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct InvoiceDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sdInvoices: [SDInvoice]
    @Query private var sdClients: [SDClient]
    @Query private var sdProfiles: [SDCompanyProfile]
    
    let invoice: Invoice
    @State private var showingEdit = false
    @State private var showingExportLanguage = false
    @State private var exportLanguage: PDFLanguage = .german
    @State private var showingExchangeRateDialog = false
    @State private var exchangeRateInput: String = ""
    @State private var showingDeleteConfirmation = false
    
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    var client: Client? {
        if usesSwiftData {
            return sdClients.first { $0.id == invoice.clientId }?.toLegacy()
        }
        return appState.clients.first { $0.id == invoice.clientId }
    }
    
    var currentInvoice: Invoice {
        if usesSwiftData {
            return sdInvoices.first { $0.id == invoice.id }?.toLegacy() ?? invoice
        }
        return appState.invoices.first { $0.id == invoice.id } ?? invoice
    }
    
    var isVatExempt: Bool {
        if usesSwiftData {
            return sdProfiles.first?.isVatExempt ?? false
        }
        return appState.companyProfile?.isVatExempt ?? false
    }
    var displayTotal: Double { isVatExempt ? currentInvoice.subtotal : currentInvoice.total }
    
    // MARK: - Body Sections (split to help compiler)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentInvoice.invoiceNumber)
                    .font(.system(size: 24, weight: .semibold))
                Text(client?.name ?? "—")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(displayTotal))
                    .font(.system(size: 24, weight: .semibold))
                StatusBadge(status: currentInvoice.status)
            }
        }
    }
    
    private var datesSection: some View {
        HStack(spacing: 32) {
            DateBlock(label: "Issued", date: currentInvoice.issueDate)
            DateBlock(label: "Due", date: currentInvoice.dueDate, isOverdue: currentInvoice.isOverdue)
            if let paid = currentInvoice.paidAt {
                DateBlock(label: "Paid", date: paid)
            }
        }
    }
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                ForEach(currentInvoice.lineItems) { item in
                    lineItemRow(item)
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func lineItemRow(_ item: LineItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.description)
                    .font(.system(size: 14))
                Spacer()
                Text("\(formatQty(item.quantity)) × \(formatCurrency(item.unitPrice))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(formatCurrency(item.total))
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 10)
            if item.id != currentInvoice.lineItems.last?.id {
                Divider()
            }
        }
    }
    
    private var totalsSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 32) {
                    Text("Subtotal").foregroundColor(.secondary)
                    Text(formatCurrency(currentInvoice.subtotal))
                }
                .font(.system(size: 14))
                
                if isVatExempt {
                    Text("VAT exempt (§19 UStG)")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                } else {
                    ForEach(currentInvoice.taxBreakdown, id: \.rate) { breakdown in
                        HStack(spacing: 32) {
                            Text("VAT \(Int(breakdown.rate))%").foregroundColor(.secondary)
                            Text(formatCurrency(breakdown.amount))
                        }
                        .font(.system(size: 14))
                    }
                }
                
                Divider().frame(width: 180)
                
                HStack(spacing: 32) {
                    Text("Total")
                    Text(formatCurrency(displayTotal))
                }
                .font(.system(size: 17, weight: .semibold))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    Divider()
                    datesSection
                    lineItemsSection
                    totalsSection
                    
                    // Actions
                    HStack(spacing: 12) {
                        if currentInvoice.status == .draft {
                            Button(action: markAsSent) {
                                Text("Mark Sent")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if currentInvoice.status == .sent || currentInvoice.status == .overdue {
                            Button(action: markAsPaid) {
                                Text("Mark Paid")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Menu {
                            Button("Deutsch (German)") {
                                exportLanguage = .german
                                exportPDF()
                            }
                            Button("English") {
                                exportLanguage = .english
                                exportPDF()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc")
                                Text("Export")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Spacer()
                        
                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(32)
            }
            .navigationTitle("Invoice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if currentInvoice.status == .draft {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                InvoiceEditorView(invoice: currentInvoice).environmentObject(appState)
            }
            .alert("Delete Invoice", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteInvoice() }
            } message: {
                Text("Are you sure you want to delete invoice \(currentInvoice.invoiceNumber)? This action cannot be undone.")
            }
            .sheet(isPresented: $showingExchangeRateDialog) {
                ExchangeRateDialog(
                    invoice: currentInvoice,
                    baseCurrency: usesSwiftData
                        ? (sdProfiles.first?.defaultCurrency ?? .eur)
                        : (appState.companyProfile?.defaultCurrency ?? .eur),
                    exchangeRateInput: $exchangeRateInput,
                    onConfirm: { rate, baseAmount in
                        if usesSwiftData {
                            if let sdInvoice = sdInvoices.first(where: { $0.id == invoice.id }) {
                                sdInvoice.status = .paid
                                sdInvoice.paidAt = Date()
                                sdInvoice.paidExchangeRate = rate
                                sdInvoice.paidAmountInBaseCurrency = baseAmount
                                sdInvoice.updatedAt = Date()
                                try? modelContext.save()
                            }
                        } else {
                            if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                                appState.invoices[i].markAsPaid(exchangeRate: rate, amountInBaseCurrency: baseAmount)
                                appState.saveInvoices()
                            }
                        }
                        showingExchangeRateDialog = false
                    },
                    onCancel: {
                        showingExchangeRateDialog = false
                    }
                )
            }
        }
    }
    
    func markAsSent() {
        if usesSwiftData {
            if let sdInvoice = sdInvoices.first(where: { $0.id == invoice.id }) {
                sdInvoice.status = .sent
                sdInvoice.updatedAt = Date()
                try? modelContext.save()
            }
        } else {
            if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                appState.invoices[i].markAsSent()
                appState.saveInvoices()
            }
        }
    }
    
    func deleteInvoice() {
        if usesSwiftData {
            if let sdInvoice = sdInvoices.first(where: { $0.id == invoice.id }) {
                modelContext.delete(sdInvoice)
                try? modelContext.save()
            }
        } else {
            if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                appState.invoices.remove(at: i)
                appState.saveInvoices()
            }
        }
        dismiss()
    }
    
    func markAsPaid() {
        let baseCurrency = usesSwiftData
            ? (sdProfiles.first?.defaultCurrency ?? .eur)
            : (appState.companyProfile?.defaultCurrency ?? .eur)
        
        // If currencies differ, show exchange rate dialog
        if currentInvoice.currency != baseCurrency {
            exchangeRateInput = ""
            showingExchangeRateDialog = true
        } else {
            // Same currency, no conversion needed
            if usesSwiftData {
                if let sdInvoice = sdInvoices.first(where: { $0.id == invoice.id }) {
                    sdInvoice.status = .paid
                    sdInvoice.paidAt = Date()
                    sdInvoice.updatedAt = Date()
                    try? modelContext.save()
                }
            } else {
                if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
                    appState.invoices[i].markAsPaid()
                    appState.saveInvoices()
                }
            }
        }
    }
    
    func exportPDF() {
        guard let client = client else { return }
        
        // Use SwiftData profile if available
        let profile: CompanyProfile
        if usesSwiftData, let sdProfile = sdProfiles.first {
            profile = sdProfile.toLegacy()
        } else if let legacyProfile = appState.companyProfile {
            profile = legacyProfile
        } else {
            return
        }
        
        #if os(macOS)
        let fileName = "\(currentInvoice.invoiceNumber).pdf"
        
        // Check for default export path
        if !profile.defaultExportPath.isEmpty {
            let folderURL = URL(fileURLWithPath: profile.defaultExportPath)
            let fileURL = folderURL.appendingPathComponent(fileName)
            
            // Check if folder exists and is writable
            if FileManager.default.isWritableFile(atPath: profile.defaultExportPath) {
                _ = PDFGenerator.saveInvoicePDF(invoice: currentInvoice, client: client, companyProfile: profile, to: fileURL, language: exportLanguage)
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: folderURL.path)
                return
            }
        }
        
        // Fallback to save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName
        panel.begin { [exportLanguage] r in
            if r == .OK, let url = panel.url {
                _ = PDFGenerator.saveInvoicePDF(invoice: currentInvoice, client: client, companyProfile: profile, to: url, language: exportLanguage)
            }
        }
        #endif
    }
    
    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currentInvoice.currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "€0"
    }
    
    func formatQty(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.2f", q)
    }
}

struct DateBlock: View {
    let label: String
    let date: Date
    var isOverdue: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(formatDate(date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isOverdue ? .red : .primary)
        }
    }
    
    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}

struct StatusBadge: View {
    let status: InvoiceStatus
    
    var color: Color {
        switch status {
        case .paid: return .green
        case .overdue: return .red
        case .sent: return .blue
        case .cancelled: return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct InvoiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        InvoiceDetailView(invoice: Invoice(clientId: UUID())).environmentObject(AppState())
    }
}

// MARK: - Exchange Rate Dialog

struct ExchangeRateDialog: View {
    let invoice: Invoice
    let baseCurrency: Currency
    @Binding var exchangeRateInput: String
    let onConfirm: (Double, Double) -> Void
    let onCancel: () -> Void
    
    var isVatExempt: Bool = false
    
    @State private var isLoading = true
    @State private var fetchError: String? = nil
    @State private var rateSource: String = ""
    
    var invoiceTotal: Double {
        isVatExempt ? invoice.subtotal : invoice.total
    }
    
    var exchangeRate: Double? {
        Double(exchangeRateInput.replacingOccurrences(of: ",", with: "."))
    }
    
    var convertedAmount: Double? {
        guard let rate = exchangeRate, rate > 0 else { return nil }
        return invoiceTotal * rate
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Currency Conversion")
                    .font(.system(size: 18, weight: .semibold))
                
                Text(fetchError != nil ? "Enter the exchange rate manually" : "Fetching current exchange rate...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Invoice info
            VStack(spacing: 8) {
                HStack {
                    Text("Invoice Total:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(invoiceTotal, currency: invoice.currency))
                        .font(.system(size: 15, weight: .semibold))
                }
                
                HStack {
                    Text("Base Currency:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(baseCurrency.symbol) \(baseCurrency.rawValue)")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .font(.system(size: 14))
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Exchange rate input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exchange Rate")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else if !rateSource.isEmpty {
                        Text("(\(rateSource))")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    } else if fetchError != nil {
                        Text("(manual)")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    Text("1 \(invoice.currency.rawValue) =")
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $exchangeRateInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 100)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(baseCurrency.rawValue)
                        .foregroundColor(.secondary)
                    
                    // Refresh button
                    Button(action: { fetchExchangeRate() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                
                if let error = fetchError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            
            // Converted amount preview
            if let converted = convertedAmount {
                HStack {
                    Text("You received:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(converted, currency: baseCurrency))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button(action: {
                    if let rate = exchangeRate, let converted = convertedAmount {
                        onConfirm(rate, converted)
                    }
                }) {
                    Text("Mark as Paid")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .background(exchangeRate != nil ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(exchangeRate == nil)
            }
        }
        .padding(24)
        .frame(width: 380, height: 480)
        .onAppear {
            fetchExchangeRate()
        }
    }
    
    func fetchExchangeRate() {
        isLoading = true
        fetchError = nil
        rateSource = ""
        
        // Using Frankfurter API (free, no API key needed)
        let from = invoice.currency.rawValue
        let to = baseCurrency.rawValue
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(from)&to=\(to)") else {
            fetchError = "Invalid currency"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    fetchError = "No internet connection"
                    print("Exchange rate fetch error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    fetchError = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let rates = json["rates"] as? [String: Double],
                       let rate = rates[to] {
                        exchangeRateInput = String(format: "%.4f", rate)
                        rateSource = "live rate"
                    } else {
                        fetchError = "Could not parse rate"
                    }
                } catch {
                    fetchError = "Failed to decode response"
                }
            }
        }.resume()
    }
    
    func formatCurrency(_ value: Double, currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }
}
