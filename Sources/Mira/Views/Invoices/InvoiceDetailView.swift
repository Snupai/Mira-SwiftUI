import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct InvoiceDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) private var colors
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
    @State private var resolvedInvoice: Invoice?
    @State private var operationError: String?
    @State private var showingOperationError = false
    @State private var exportedURL: URL?
    @State private var showingExportSuccess = false
    
    private var usesSwiftData: Bool {
        MigrationService.shared.useSwiftData
    }
    
    var client: Client? {
        if usesSwiftData {
            return sdClients.first { $0.id == currentInvoice.clientId }?.toLegacy()
        }
        return appState.clients.first { $0.id == currentInvoice.clientId }
    }
    
    private var storedInvoice: SDInvoice? { sdInvoices.first { $0.id == invoice.id } }
    var currentInvoice: Invoice { resolvedInvoice ?? invoice }
    private func refreshInvoice() {
        resolvedInvoice = usesSwiftData ? storedInvoice?.toLegacy() : appState.invoices.first { $0.id == invoice.id }
    }

    var isVatExempt: Bool {
        if usesSwiftData {
            return sdProfiles.first?.isVatExempt ?? false
        }
        return appState.companyProfile?.isVatExempt ?? false
    }
    var displayTotal: Double { isVatExempt ? currentInvoice.taxableAmount : currentInvoice.total }
    
    // MARK: - Body Sections (split to help compiler)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentInvoice.invoiceNumber)
                    .font(.system(size: 24, weight: .semibold))
                Text(client?.name ?? "—")
                    .font(.system(size: 15))
                    .foregroundColor(colors.subtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(displayTotal))
                    .font(.system(size: 24, weight: .semibold))
                StatusBadge(status: currentInvoice.effectiveStatus)
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
                .foregroundColor(colors.subtext)
            
            VStack(spacing: 0) {
                ForEach(currentInvoice.lineItems) { item in
                    lineItemRow(item)
                }
            }
            .padding(16)
            .background(colors.surface0)
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
                    .foregroundColor(colors.subtext)
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
                    Text("Subtotal").foregroundColor(colors.subtext)
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
                            Text("VAT \(Int(breakdown.rate))%").foregroundColor(colors.subtext)
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
                                    .background(colors.accent)
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
                            .background(colors.surface1)
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
            .background(colors.base)
            .foregroundStyle(colors.text)
            .navigationTitle("Invoice")
            .onAppear { refreshInvoice() }
            .onChange(of: storedInvoice?.updatedAt) { _, _ in refreshInvoice() }
            .onChange(of: appState.invoices.first { $0.id == invoice.id }?.updatedAt) { _, _ in refreshInvoice() }
            .alert("Action could not be completed", isPresented: $showingOperationError) {
                Button("OK", role: .cancel) { }
            } message: { Text(operationError ?? "Please try again.") }
            .alert("PDF saved", isPresented: $showingExportSuccess) {
                Button("Show in Finder") {
                    if let exportedURL { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]) }
                }
                Button("Done", role: .cancel) { }
            } message: { Text(exportedURL?.lastPathComponent ?? "Your PDF is ready.") }
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
                        try recordPayment(rate: rate, baseAmount: baseAmount)
                        showingExchangeRateDialog = false
                    },
                    onCancel: {
                        showingExchangeRateDialog = false
                    },
                    isVatExempt: isVatExempt
                )
            }
        }
    }
    
    private func report(_ error: Error) {
        operationError = error.localizedDescription
        showingOperationError = true
    }

    private func saveMutation(_ swiftData: (SDInvoice) -> Void, legacy: (inout Invoice) -> Void) throws {
        if usesSwiftData {
            guard let stored = storedInvoice else { throw MiraPersistenceError.missingRecord }
            swiftData(stored)
            do { try modelContext.save() } catch { modelContext.rollback(); throw error }
        } else {
            var invoices = appState.invoices
            guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { throw MiraPersistenceError.missingRecord }
            legacy(&invoices[index])
            try appState.persistInvoices(invoices)
            appState.invoices = invoices
        }
        refreshInvoice()
    }

    func markAsSent() {
        let numbers = usesSwiftData ? sdInvoices.filter { $0.id != invoice.id }.map(\.invoiceNumber) : appState.invoices.filter { $0.id != invoice.id }.map(\.invoiceNumber)
        let issues = InvoiceValidation.issues(for: currentInvoice, hasClient: client != nil, existingNumbers: numbers)
        guard issues.isEmpty else { operationError = issues.joined(separator: "\n"); showingOperationError = true; return }
        do { try saveMutation({ $0.markAsSent() }, legacy: { $0.markAsSent() }) }
        catch { report(error) }
    }

    func deleteInvoice() {
        do {
            if usesSwiftData {
                guard let stored = storedInvoice else { throw MiraPersistenceError.missingRecord }
                modelContext.delete(stored)
                do { try modelContext.save() } catch { modelContext.rollback(); throw error }
            } else {
                let invoices = appState.invoices.filter { $0.id != invoice.id }
                try appState.persistInvoices(invoices)
                appState.invoices = invoices
            }
            dismiss()
        } catch { report(error) }
    }

    func markAsPaid() {
        let baseCurrency = usesSwiftData ? sdProfiles.first?.defaultCurrency ?? .eur : appState.companyProfile?.defaultCurrency ?? .eur
        if currentInvoice.currency != baseCurrency {
            exchangeRateInput = ""
            showingExchangeRateDialog = true
        } else {
            do { try recordPayment(rate: nil, baseAmount: nil) }
            catch { report(error) }
        }
    }

    private func recordPayment(rate: Double?, baseAmount: Double?) throws {
        try saveMutation({ $0.markAsPaid(exchangeRate: rate, amountInBaseCurrency: baseAmount) },
                         legacy: { $0.markAsPaid(exchangeRate: rate, amountInBaseCurrency: baseAmount) })
    }

    func exportPDF() {
        guard let client else { report(MiraPersistenceError.missingClient); return }
        guard let profile = CompanyProfileStore.resolve(sdProfiles, legacy: appState.companyProfile) else {
            report(MiraPersistenceError.missingRecord); return
        }
        let snapshot = currentInvoice
        let fileName = snapshot.invoiceNumber.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
        let language = exportLanguage
        func save(to url: URL) {
            guard PDFGenerator.saveInvoicePDF(invoice: snapshot, client: client, companyProfile: profile, to: url, language: language) else {
                report(MiraPersistenceError.exportFailed); return
            }
            exportedURL = url
            showingExportSuccess = true
        }
        if !profile.defaultExportPath.isEmpty {
            let folder = URL(fileURLWithPath: profile.defaultExportPath)
            let destination = folder.appendingPathComponent(fileName)
            if FileManager.default.isWritableFile(atPath: folder.path), !FileManager.default.fileExists(atPath: destination.path) {
                save(to: destination)
                return
            }
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName
        if !profile.defaultExportPath.isEmpty { panel.directoryURL = URL(fileURLWithPath: profile.defaultExportPath) }
        panel.begin { response in
            if response == .OK, let url = panel.url { save(to: url) }
        }
    }

    func formatCurrency(_ value: Double) -> String { MiraFormat.currency(value, currentInvoice.currency) }

    func formatQty(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.2f", q)
    }
}

struct DateBlock: View {
    @Environment(\.themeColors) private var colors
    let label: String
    let date: Date
    var isOverdue: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(colors.subtext)
            Text(formatDate(date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isOverdue ? .red : .primary)
        }
    }
    
    func formatDate(_ d: Date) -> String { MiraFormat.date(d) }
}

struct StatusBadge: View {
    @Environment(\.themeColors) private var colors
    let status: InvoiceStatus
    
    var color: Color {
        switch status {
        case .paid: return .green
        case .overdue: return .red
        case .sent: return colors.accent
        case .cancelled: return .orange
        default: return colors.subtext
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
    @Environment(\.themeColors) private var colors
    let invoice: Invoice
    let baseCurrency: Currency
    @Binding var exchangeRateInput: String
    let onConfirm: (Double, Double) throws -> Void
    let onCancel: () -> Void
    
    var isVatExempt: Bool = false
    
    @State private var isLoading = true
    @State private var fetchError: String? = nil
    @State private var rateSource: String = ""
    @State private var saveError: String?
    @State private var showingSaveError = false
    
    var invoiceTotal: Double {
        isVatExempt ? invoice.taxableAmount : invoice.total
    }
    
    var exchangeRate: Double? {
        Double(exchangeRateInput.replacingOccurrences(of: ",", with: "."))
    }
    
    var convertedAmount: Double? {
        guard let rate = exchangeRate, rate.isFinite, rate > 0, (invoiceTotal * rate).isFinite else { return nil }
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
                
                Text(isLoading ? "Fetching reference exchange rate…" : "Confirm the rate used for your payment.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.subtext)
                    .multilineTextAlignment(.center)
            }
            
            // Invoice info
            VStack(spacing: 8) {
                HStack {
                    Text("Invoice Total:")
                        .foregroundColor(colors.subtext)
                    Spacer()
                    Text(formatCurrency(invoiceTotal, currency: invoice.currency))
                        .font(.system(size: 15, weight: .semibold))
                }
                
                HStack {
                    Text("Base Currency:")
                        .foregroundColor(colors.subtext)
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
                        .foregroundColor(colors.subtext)
                    
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
                        .foregroundColor(colors.subtext)
                    TextField("0.00", text: $exchangeRateInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .accessibilityLabel("Exchange rate")
                        .frame(width: 100)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(baseCurrency.rawValue)
                        .foregroundColor(colors.subtext)
                    
                    // Refresh button
                    Button(action: { fetchExchangeRate() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh reference exchange rate")
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
                    Text("Converted amount:")
                        .foregroundColor(colors.subtext)
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
                        do { try onConfirm(rate, converted) }
                        catch { saveError = error.localizedDescription; showingSaveError = true }
                    }
                }) {
                    Text("Mark as Paid")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .background(convertedAmount != nil ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(convertedAmount == nil)
            }
        }
        .padding(24)
        .frame(width: 420, height: 520)
        .background(colors.base)
        .foregroundStyle(colors.text)
        .alert("Payment could not be saved", isPresented: $showingSaveError) {
            Button("Keep Editing", role: .cancel) { }
        } message: { Text(saveError ?? "Please try again.") }
        .onAppear {
            fetchExchangeRate()
        }
    }
    
    func fetchExchangeRate() {
        isLoading = true
        fetchError = nil
        rateSource = ""
        
        let inputAtRequest = exchangeRateInput
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
                        if exchangeRateInput == inputAtRequest { exchangeRateInput = String(format: "%.4f", rate) }
                        rateSource = "reference rate"
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
        MiraFormat.currency(value, currency)
    }
}
