import SwiftUI
import SwiftData
import os
#if os(macOS)
import AppKit
#endif

/// Shared mutations and export for invoices, so the table context menu, the
/// inspector and the dashboard all behave identically. Writes to SwiftData
/// when migrated, otherwise to the legacy JSON store in `AppState`.
@MainActor
struct InvoiceActions {
    let modelContext: ModelContext
    let appState: AppState
    let sdInvoices: [SDInvoice]

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    // MARK: Status transitions

    func markSent(_ invoice: Invoice) {
        mutate(invoice) { sd in
            sd.status = .sent
            sd.sentAt = Date()
        } legacy: { $0.markAsSent() }
    }

    func markPaid(_ invoice: Invoice, exchangeRate: Double? = nil, amountInBaseCurrency: Double? = nil) {
        mutate(invoice) { sd in
            sd.status = .paid
            sd.paidAt = Date()
            sd.paidExchangeRate = exchangeRate
            sd.paidAmountInBaseCurrency = amountInBaseCurrency
        } legacy: { $0.markAsPaid(exchangeRate: exchangeRate, amountInBaseCurrency: amountInBaseCurrency) }
    }

    func cancel(_ invoice: Invoice) {
        mutate(invoice) { sd in
            sd.status = .cancelled
        } legacy: { $0.cancel() }
    }

    /// Moves a sent (not yet paid) invoice back to draft so it can be edited.
    func revertToDraft(_ invoice: Invoice) {
        mutate(invoice) { sd in
            sd.status = .draft
            sd.sentAt = nil
        } legacy: { legacy in
            legacy.status = .draft
            legacy.sentAt = nil
            legacy.updatedAt = Date()
        }
    }

    func delete(_ invoice: Invoice) {
        if usesSwiftData {
            guard let sd = sdInvoices.first(where: { $0.id == invoice.id }) else { return }
            modelContext.delete(sd)
            save()
        } else {
            appState.invoices.removeAll { $0.id == invoice.id }
            appState.saveInvoices()
        }
    }

    // MARK: Export

    /// Writes the PDF to the configured export folder, or asks with a save
    /// panel. Reveals the file in Finder when written to the default folder.
    func exportPDF(_ invoice: Invoice, client: Client?, profile: CompanyProfile?, language: PDFLanguage) {
        guard let client, let profile else {
            Log.app.error("Export aborted: missing client or profile for invoice \(invoice.invoiceNumber, privacy: .public)")
            return
        }
        #if os(macOS)
        let fileName = "\(invoice.invoiceNumber).pdf"
        if !profile.defaultExportPath.isEmpty,
           FileManager.default.isWritableFile(atPath: profile.defaultExportPath) {
            let folderURL = URL(fileURLWithPath: profile.defaultExportPath)
            let fileURL = folderURL.appendingPathComponent(fileName)
            if PDFGenerator.saveInvoicePDF(invoice: invoice, client: client, companyProfile: profile, to: fileURL, language: language) {
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: folderURL.path)
            }
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            _ = PDFGenerator.saveInvoicePDF(invoice: invoice, client: client, companyProfile: profile, to: url, language: language)
        }
        #endif
    }

    // MARK: Plumbing

    private func mutate(_ invoice: Invoice, swiftData: (SDInvoice) -> Void, legacy: (inout Invoice) -> Void) {
        if usesSwiftData {
            guard let sd = sdInvoices.first(where: { $0.id == invoice.id }) else { return }
            swiftData(sd)
            sd.updatedAt = Date()
            save()
        } else {
            guard let index = appState.invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
            legacy(&appState.invoices[index])
            appState.saveInvoices()
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Log.data.error("Invoice save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
