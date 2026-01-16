import SwiftUI
#if os(macOS)
import AppKit
#endif

struct InvoiceDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let invoice: Invoice
    @State private var showingEdit = false
    @State private var showingExportLanguage = false
    @State private var exportLanguage: PDFLanguage = .german
    
    var client: Client? { appState.clients.first { $0.id == invoice.clientId } }
    var currentInvoice: Invoice { appState.invoices.first { $0.id == invoice.id } ?? invoice }
    var isVatExempt: Bool { appState.companyProfile?.isVatExempt ?? false }
    var displayTotal: Double { isVatExempt ? currentInvoice.subtotal : currentInvoice.total }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
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
                    
                    Divider()
                    
                    // Dates
                    HStack(spacing: 32) {
                        DateBlock(label: "Issued", date: currentInvoice.issueDate)
                        DateBlock(label: "Due", date: currentInvoice.dueDate, isOverdue: currentInvoice.isOverdue)
                        if let paid = currentInvoice.paidAt {
                            DateBlock(label: "Paid", date: paid)
                        }
                    }
                    
                    // Line Items
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 0) {
                            ForEach(currentInvoice.lineItems) { item in
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
                        .padding(16)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Totals
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
                                ForEach(currentInvoice.taxBreakdown, id: \.rate) { b in
                                    HStack(spacing: 32) {
                                        Text("VAT \(Int(b.rate))%").foregroundColor(.secondary)
                                        Text(formatCurrency(b.amount))
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
                        
                        if let client = client, !client.email.isEmpty {
                            Button(action: openInMail) {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope")
                                    Text("Email")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
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
        }
    }
    
    func markAsSent() {
        if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
            appState.invoices[i].markAsSent()
            appState.saveInvoices()
        }
    }
    
    func markAsPaid() {
        if let i = appState.invoices.firstIndex(where: { $0.id == invoice.id }) {
            appState.invoices[i].markAsPaid()
            appState.saveInvoices()
        }
    }
    
    func exportPDF() {
        guard let client = client, let profile = appState.companyProfile else { return }
        
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(currentInvoice.invoiceNumber).pdf"
        panel.begin { [exportLanguage] r in
            if r == .OK, let url = panel.url {
                _ = PDFGenerator.saveInvoicePDF(invoice: currentInvoice, client: client, companyProfile: profile, to: url, language: exportLanguage)
            }
        }
        #endif
    }
    
    func openInMail() {
        guard let client = client, let profile = appState.companyProfile else { return }
        
        // First export PDF to Downloads
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let pdfURL = downloadsURL.appendingPathComponent("\(currentInvoice.invoiceNumber).pdf")
        let saved = PDFGenerator.saveInvoicePDF(invoice: currentInvoice, client: client, companyProfile: profile, to: pdfURL)
        
        // Show alert
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "PDF Exported"
        alert.informativeText = saved 
            ? "The invoice PDF has been saved to your Downloads folder.\n\nPlease attach it manually to the email that will open."
            : "Could not export PDF. The email will open without attachment."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Email")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let subject = "Rechnung \(currentInvoice.invoiceNumber)"
            
            // Get template and replace placeholders
            var body = profile.emailTemplate
            body = body.replacingOccurrences(of: "{invoiceNumber}", with: currentInvoice.invoiceNumber)
            body = body.replacingOccurrences(of: "{totalAmount}", with: formatCurrency(displayTotal))
            body = body.replacingOccurrences(of: "{dueDate}", with: formatDate(currentInvoice.dueDate))
            body = body.replacingOccurrences(of: "{companyName}", with: profile.companyName)
            body = body.replacingOccurrences(of: "{ownerName}", with: profile.ownerName.isEmpty ? profile.companyName : profile.ownerName)
            body = body.replacingOccurrences(of: "{clientName}", with: client.name)
            body = body.replacingOccurrences(of: "{accountHolder}", with: profile.accountHolder.isEmpty ? profile.companyName : profile.accountHolder)
            body = body.replacingOccurrences(of: "{iban}", with: profile.iban)
            body = body.replacingOccurrences(of: "{bic}", with: profile.bic)
            
            // Manual encoding - %0D%0A for newlines
            let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? subject
            let encodedBody = body
                .components(separatedBy: "\n")
                .map { $0.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? $0 }
                .joined(separator: "%0D%0A")
            
            if let url = URL(string: "mailto:\(client.email)?subject=\(encodedSubject)&body=\(encodedBody)") {
                NSWorkspace.shared.open(url)
            }
        }
        #endif
    }
    
    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: d)
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
