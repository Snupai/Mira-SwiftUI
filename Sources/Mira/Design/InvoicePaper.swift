import SwiftUI

/// A live rendering of an invoice as a sheet of paper.
///
/// This is Mira's signature element: the document the freelancer is actually
/// producing, drawn from real data, white in both light and dark mode because
/// paper is paper. It appears in the inspector, in the editor, and assembles
/// itself during onboarding. Layout is proportional to `width` so the same
/// view works as a 200pt thumbnail or a 600pt preview.
struct InvoicePaper: View {
    let invoice: Invoice?
    let client: Client?
    let profile: CompanyProfile
    var language: PDFLanguage = .german
    var width: CGFloat = 320
    /// Highlights the region currently being edited (used in onboarding).
    var focus: Focus? = nil

    enum Focus { case company, address, tax, bank, branding }

    private var u: CGFloat { width / 100 }          // one "unit" = 1% of width
    private var brand: Color { Color(hex: profile.brandColorHex) ?? .blue }
    private var isGerman: Bool { language == .german }
    private var currency: Currency { invoice?.currency ?? profile.defaultCurrency }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer().frame(height: u * 7)
            addressAndMeta
            Spacer().frame(height: u * 7)
            lineItems
            Spacer().frame(height: u * 4)
            totals
            Spacer(minLength: u * 4)
            footer
        }
        .padding(u * 8)
        .frame(width: width, height: width * 1.4142, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.paper, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.paper, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: u * 3, y: u * 1.5)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: u * 1) {
                if let data = profile.logoData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: u * 8)
                        .frame(maxWidth: u * 30, alignment: .leading)
                } else {
                    paperText(profile.companyName.isEmpty ? placeholder(isGerman ? "Ihr Unternehmen" : "Your company") : profile.companyName,
                              size: 5.2, weight: .semibold, color: brand)
                }
                if !profile.ownerName.isEmpty {
                    paperText(profile.ownerName, size: 2.6, color: ink(0.6))
                }
            }
            .highlighted(focus == .company || focus == .branding)
            Spacer()
            VStack(alignment: .trailing, spacing: u * 0.8) {
                paperText(isGerman ? "Rechnung" : "Invoice", size: 5.2, weight: .semibold, color: ink(0.9))
                paperText(invoice?.invoiceNumber.nilIfEmpty ?? profile.generateInvoiceNumber(), size: 2.8, color: ink(0.6))
            }
        }
    }

    private var addressAndMeta: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: u * 0.6) {
                paperText(isGerman ? "Rechnungsempfänger" : "Bill to", size: 2.2, weight: .medium, color: ink(0.45))
                if let client {
                    paperText(client.name, size: 3, weight: .medium, color: ink(0.9))
                    if !client.contactPerson.isEmpty { paperText(client.contactPerson, size: 2.6, color: ink(0.7)) }
                    ForEach(client.formattedAddress.split(separator: "\n").map(String.init), id: \.self) {
                        paperText($0, size: 2.6, color: ink(0.7))
                    }
                } else {
                    placeholderBlock(lines: 3)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: u * 1.2) {
                metaRow(isGerman ? "Datum" : "Date", invoice.map { Dates.medium.string(from: $0.issueDate) } ?? Dates.medium.string(from: Date()))
                metaRow(isGerman ? "Fällig" : "Due", invoice.map { Dates.medium.string(from: $0.dueDate) } ?? "\(profile.defaultPaymentTermsDays) \(isGerman ? "Tage" : "days")")
                if !profile.vatId.isEmpty {
                    metaRow("USt-IdNr.", profile.vatId).highlighted(focus == .tax)
                } else if !profile.taxNumber.isEmpty {
                    metaRow(isGerman ? "Steuernr." : "Tax no.", profile.taxNumber).highlighted(focus == .tax)
                } else if focus == .tax {
                    metaRow("USt-IdNr.", "DE…").highlighted(true)
                }
            }
            .frame(width: u * 36, alignment: .leading)
            // Sender line above the recipient, as on German letter paper.
            .overlay(alignment: .topLeading) { EmptyView() }
        }
        .overlay(alignment: .topLeading) {
            // Return-address line (tiny, like a window envelope line).
            if !profile.street.isEmpty || focus == .address {
                paperText(senderLine, size: 1.8, color: ink(0.45))
                    .offset(y: -u * 3.4)
                    .highlighted(focus == .address)
            }
        }
    }

    private var senderLine: String {
        let parts = [profile.companyName, profile.street, "\(profile.postalCode) \(profile.city)".trimmingCharacters(in: .whitespaces)]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (isGerman ? "Absenderzeile" : "Sender line") : parts.joined(separator: " · ")
    }

    private var lineItems: some View {
        let items = invoice?.lineItems.filter { !$0.description.isEmpty || $0.unitPrice != 0 } ?? []
        return VStack(spacing: 0) {
            HStack {
                paperText(isGerman ? "Beschreibung" : "Description", size: 2.2, weight: .medium, color: ink(0.5))
                Spacer()
                paperText(isGerman ? "Menge" : "Qty", size: 2.2, weight: .medium, color: ink(0.5)).frame(width: u * 10, alignment: .trailing)
                paperText(isGerman ? "Preis" : "Price", size: 2.2, weight: .medium, color: ink(0.5)).frame(width: u * 16, alignment: .trailing)
                paperText(isGerman ? "Betrag" : "Amount", size: 2.2, weight: .medium, color: ink(0.5)).frame(width: u * 16, alignment: .trailing)
            }
            .padding(.bottom, u * 1.2)
            Rectangle().fill(brand).frame(height: max(1, u * 0.35))
            if items.isEmpty {
                ForEach(0..<2, id: \.self) { _ in
                    HStack {
                        placeholderBar(widthFraction: 0.45)
                        Spacer()
                        placeholderBar(widthFraction: 0.12)
                    }
                    .padding(.vertical, u * 2)
                    Rectangle().fill(ink(0.08)).frame(height: 0.5)
                }
            } else {
                ForEach(items) { item in
                    HStack {
                        paperText(item.description.nilIfEmpty ?? "—", size: 2.6, color: ink(0.85))
                        Spacer()
                        paperText(Money.quantity(item.quantity), size: 2.6, color: ink(0.7)).frame(width: u * 10, alignment: .trailing)
                        paperText(Money.string(item.unitPrice, currency), size: 2.6, color: ink(0.7)).frame(width: u * 16, alignment: .trailing)
                        paperText(Money.string(item.total, currency), size: 2.6, weight: .medium, color: ink(0.9)).frame(width: u * 16, alignment: .trailing)
                    }
                    .padding(.vertical, u * 1.8)
                    Rectangle().fill(ink(0.08)).frame(height: 0.5)
                }
            }
        }
    }

    private var totals: some View {
        let subtotal = invoice?.subtotal ?? 0
        let breakdown = invoice?.taxBreakdown ?? []
        let total = profile.isVatExempt ? subtotal : (invoice?.total ?? 0)
        return HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: u * 1) {
                totalRow(isGerman ? "Zwischensumme" : "Subtotal", Money.string(subtotal, currency), size: 2.6, color: ink(0.6))
                if profile.isVatExempt {
                    paperText(isGerman ? "Umsatzsteuerfrei gemäß §19 UStG" : "VAT exempt under §19 UStG", size: 2.1, color: ink(0.5))
                        .highlighted(focus == .tax)
                } else {
                    ForEach(breakdown, id: \.rate) { b in
                        totalRow("\(isGerman ? "USt." : "VAT") \(Int(b.rate)) %", Money.string(b.amount, currency), size: 2.6, color: ink(0.6))
                    }
                }
                Rectangle().fill(ink(0.9)).frame(width: u * 36, height: max(1, u * 0.3)).padding(.vertical, u * 0.6)
                totalRow(isGerman ? "Gesamtbetrag" : "Total", Money.string(total, currency), size: 3.4, weight: .semibold, color: ink(0.95))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: u * 1.2) {
            Rectangle().fill(ink(0.1)).frame(height: 0.5)
            HStack(alignment: .top, spacing: u * 4) {
                VStack(alignment: .leading, spacing: u * 0.5) {
                    paperText(profile.companyName.nilIfEmpty ?? placeholder(isGerman ? "Firma" : "Company"), size: 2, color: ink(0.55))
                    paperText(profile.formattedAddress.replacingOccurrences(of: "\n", with: ", ").nilIfEmpty ?? placeholder(isGerman ? "Adresse" : "Address"), size: 2, color: ink(0.55))
                        .highlighted(focus == .address)
                    if !profile.email.isEmpty { paperText(profile.email, size: 2, color: ink(0.55)) }
                }
                Spacer()
                VStack(alignment: .leading, spacing: u * 0.5) {
                    paperText(profile.bankName.nilIfEmpty ?? placeholder(isGerman ? "Bank" : "Bank"), size: 2, color: ink(0.55))
                    paperText("IBAN \(profile.iban.nilIfEmpty ?? placeholder("DE00 0000 0000 0000 0000 00"))", size: 2, color: ink(0.55))
                    if !profile.bic.isEmpty { paperText("BIC \(profile.bic)", size: 2, color: ink(0.55)) }
                }
                .highlighted(focus == .bank)
            }
        }
    }

    // MARK: Primitives

    private func paperText(_ text: String, size: CGFloat, weight: Font.Weight = .regular, color: Color) -> some View {
        Text(text)
            .font(.system(size: max(4, u * size), weight: weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .monospacedDigit()
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: u * 2) {
            paperText(label, size: 2.4, color: ink(0.45)).frame(width: u * 14, alignment: .leading)
            paperText(value, size: 2.4, weight: .medium, color: ink(0.85))
        }
    }

    private func totalRow(_ label: String, _ value: String, size: CGFloat, weight: Font.Weight = .regular, color: Color) -> some View {
        HStack(spacing: u * 4) {
            paperText(label, size: size, weight: weight, color: color)
            paperText(value, size: size, weight: weight, color: color).frame(width: u * 20, alignment: .trailing)
        }
    }

    private func placeholderBlock(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: u * 1.2) {
            ForEach(0..<lines, id: \.self) { i in
                placeholderBar(widthFraction: i == 0 ? 0.32 : 0.24)
            }
        }
        .padding(.top, u * 0.5)
    }

    private func placeholderBar(widthFraction: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: u * 0.6)
            .fill(ink(0.08))
            .frame(width: width * widthFraction, height: u * 2)
    }

    private func placeholder(_ s: String) -> String { s }
    private func ink(_ opacity: Double) -> Color { Color(white: 0.1).opacity(opacity) }

    private var accessibilitySummary: String {
        var parts = ["Invoice preview"]
        if let invoice { parts.append(invoice.invoiceNumber) }
        if let client { parts.append("for \(client.name)") }
        if let invoice { parts.append("total \(Money.string(profile.isVatExempt ? invoice.subtotal : invoice.total, invoice.currency))") }
        return parts.joined(separator: ", ")
    }
}

private extension View {
    /// Soft accent highlight used while onboarding to show which part of the
    /// paper the current step fills in.
    @ViewBuilder
    func highlighted(_ on: Bool) -> some View {
        if on {
            self
                .padding(4)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(-4)
                .animation(.easeInOut(duration: 0.25), value: on)
        } else {
            self
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview("Paper") {
    var profile = CompanyProfile()
    profile.companyName = "Studio Nord"
    profile.ownerName = "Jana Weber"
    profile.street = "Hafenstraße 12"
    profile.postalCode = "20457"
    profile.city = "Hamburg"
    profile.iban = SampleData.placeholderIBAN
    profile.bic = SampleData.placeholderBIC
    profile.bankName = "Commerzbank"
    profile.vatId = "DE123456789"
    var invoice = Invoice(clientId: UUID())
    invoice.invoiceNumber = "INV-2026-0042"
    invoice.lineItems = [
        LineItem(description: "Brand identity workshop", quantity: 1, unitPrice: 1800, vatRate: 19),
        LineItem(description: "Logo refinement, 3 rounds", quantity: 6, unitPrice: 95, vatRate: 19),
    ]
    var client = Client()
    client.name = "Acme GmbH"
    client.street = "Musterstraße 1"
    client.postalCode = "10115"
    client.city = "Berlin"
    return InvoicePaper(invoice: invoice, client: client, profile: profile, width: 420)
        .padding(40)
        .background(Color(nsColor: .windowBackgroundColor))
}
