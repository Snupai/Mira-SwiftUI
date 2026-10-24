import SwiftUI
import SwiftData
import CloudKit
import os

/// The macOS Settings window (⌘,). Each tab is a grouped Form; edits save as
/// you type, to SwiftData when migrated and to the legacy store otherwise.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var hasLoadedFromSwiftData = false
    @State private var alertContext: AlertContext?

    private var usesSwiftData: Bool { MigrationService.shared.useSwiftData }

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsTab(profile: profileBinding, chooseFolder: chooseExportFolder)
            }
            Tab("Company", systemImage: "building.2") {
                CompanySettingsTab(profile: profileBinding)
            }
            Tab("Tax & bank", systemImage: "building.columns") {
                TaxBankSettingsTab(profile: profileBinding)
            }
            Tab("Branding", systemImage: "paintpalette") {
                BrandingSettingsTab(profile: profileBinding)
            }
            Tab("Templates", systemImage: "text.document") {
                TemplatesSettingsTab(profile: profileBinding)
            }
            Tab("Appearance", systemImage: "circle.lefthalf.filled") {
                AppearanceSettingsTab()
            }
            Tab("Sync & security", systemImage: "lock.icloud") {
                SyncSettingsTab(storageSummary: storageSummary)
            }
        }
        .frame(width: 640)
        .frame(minHeight: 440)
        .alert(item: $alertContext) { $0.alert }
        .onAppear { loadProfileFromSwiftData() }
        .onChange(of: sdProfiles.count) { _, _ in loadProfileFromSwiftData() }
        .onChange(of: sdProfiles.first?.updatedAt) { _, _ in
            if usesSwiftData, let sdProfile = sdProfiles.first {
                appState.companyProfile = sdProfile.toLegacy()
            }
        }
    }

    // MARK: - Profile plumbing

    /// Whole-profile binding. Every tab edits through this so saving stays in one place.
    private var profileBinding: Binding<CompanyProfile> {
        Binding(
            get: { appState.companyProfile ?? CompanyProfile() },
            set: { newValue in
                appState.companyProfile = newValue
                saveCompanyProfile()
            }
        )
    }

    private func loadProfileFromSwiftData() {
        guard usesSwiftData else { return }
        guard !hasLoadedFromSwiftData || appState.companyProfile == nil else { return }
        if let sdProfile = sdProfiles.first {
            appState.companyProfile = sdProfile.toLegacy()
            hasLoadedFromSwiftData = true
        }
    }

    private func saveCompanyProfile() {
        if usesSwiftData, let profile = appState.companyProfile, let sdProfile = sdProfiles.first {
            updateSDProfile(sdProfile, from: profile)
            do {
                try modelContext.save()
            } catch {
                Log.data.error("Failed to save company profile: \(error.localizedDescription, privacy: .public)")
                alertContext = AlertContext(
                    title: "Couldn't save settings",
                    message: "Mira couldn't save your changes: \(error.localizedDescription)\n\nYour edits are still in memory but may be lost when the app quits. Try again or check available disk space."
                )
            }
        }
        appState.saveCompanyProfile()
    }

    private var storageSummary: String {
        if usesSwiftData {
            return sdProfiles.isEmpty
                ? "Data is stored with SwiftData. No company profile has been saved yet."
                : "Data is stored with SwiftData on this Mac."
        }
        return "Data is still in the legacy JSON files. It migrates the next time you open Mira."
    }

    private func chooseExportFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where exported PDFs are saved"
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            appState.companyProfile?.defaultExportPath = url.path
            saveCompanyProfile()
        }
        #endif
    }

    private func updateSDProfile(_ sdProfile: SDCompanyProfile, from profile: CompanyProfile) {
        sdProfile.companyName = profile.companyName
        sdProfile.ownerName = profile.ownerName
        sdProfile.email = profile.email
        sdProfile.phone = profile.phone
        sdProfile.website = profile.website
        sdProfile.street = profile.street
        sdProfile.city = profile.city
        sdProfile.postalCode = profile.postalCode
        sdProfile.country = profile.country
        sdProfile.vatId = profile.vatId
        sdProfile.taxNumber = profile.taxNumber
        sdProfile.companyRegistry = profile.companyRegistry
        sdProfile.isVatExempt = profile.isVatExempt
        sdProfile.bankName = profile.bankName
        sdProfile.iban = profile.iban
        sdProfile.bic = profile.bic
        sdProfile.accountHolder = profile.accountHolder
        sdProfile.logoData = profile.logoData
        sdProfile.brandColorHex = profile.brandColorHex
        sdProfile.defaultCurrencyRaw = profile.defaultCurrency.rawValue
        sdProfile.defaultPaymentTermsDays = profile.defaultPaymentTermsDays
        sdProfile.defaultVatRate = profile.defaultVatRate
        sdProfile.invoiceNumberPrefix = profile.invoiceNumberPrefix
        sdProfile.nextInvoiceNumber = profile.nextInvoiceNumber
        sdProfile.emailTemplateGerman = profile.emailTemplateGerman
        sdProfile.emailTemplateEnglish = profile.emailTemplateEnglish
        sdProfile.pdfFooterTemplateGerman = profile.pdfFooterTemplateGerman
        sdProfile.pdfClosingTemplateGerman = profile.pdfClosingTemplateGerman
        sdProfile.pdfNotesTemplateGerman = profile.pdfNotesTemplateGerman
        sdProfile.pdfFooterTemplateEnglish = profile.pdfFooterTemplateEnglish
        sdProfile.pdfClosingTemplateEnglish = profile.pdfClosingTemplateEnglish
        sdProfile.pdfNotesTemplateEnglish = profile.pdfNotesTemplateEnglish
        sdProfile.defaultExportPath = profile.defaultExportPath
        sdProfile.updatedAt = Date()
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Binding var profile: CompanyProfile
    let chooseFolder: () -> Void

    private var exportFolderName: String {
        profile.defaultExportPath.isEmpty ? "Ask each time" : (profile.defaultExportPath as NSString).lastPathComponent
    }

    var body: some View {
        Form {
            Section {
                TextField("Prefix", text: $profile.invoiceNumberPrefix)
                LabeledContent("Next number") {
                    HStack(spacing: Spacing.s) {
                        Text("\(profile.nextInvoiceNumber)")
                            .monospacedDigit()
                        Stepper("Next number", value: $profile.nextInvoiceNumber, in: 1...999_999)
                            .labelsHidden()
                    }
                }
            } header: {
                Text("Invoice numbering")
            } footer: {
                Text("Next invoice: \(profile.generateInvoiceNumber())")
                    .monospacedDigit()
            }

            Section("Defaults") {
                Picker("Payment terms", selection: $profile.defaultPaymentTermsDays) {
                    ForEach([7, 14, 30, 60], id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                Picker("Base currency", selection: $profile.defaultCurrency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                    }
                }
                if !profile.isVatExempt {
                    Picker("Default VAT rate", selection: $profile.defaultVatRate) {
                        Text("0 %").tag(0.0)
                        Text("7 %").tag(7.0)
                        Text("19 %").tag(19.0)
                    }
                }
            }

            Section {
                LabeledContent("PDF folder") {
                    HStack(spacing: Spacing.s) {
                        Text(exportFolderName)
                            .foregroundStyle(profile.defaultExportPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…", action: chooseFolder)
                        if !profile.defaultExportPath.isEmpty {
                            Button("Clear") { profile.defaultExportPath = "" }
                        }
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text(profile.defaultExportPath.isEmpty
                     ? "Mira asks where to save each PDF. Choose a folder to skip the dialog."
                     : "PDFs are saved straight into this folder and revealed in Finder.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Company

private struct CompanySettingsTab: View {
    @Binding var profile: CompanyProfile

    var body: some View {
        Form {
            Section("Company") {
                TextField("Company name", text: $profile.companyName)
                TextField("Your name", text: $profile.ownerName)
                TextField("Email", text: $profile.email)
                    .textContentType(.emailAddress)
                TextField("Phone", text: $profile.phone)
                    .textContentType(.telephoneNumber)
                TextField("Website", text: $profile.website)
                    .textContentType(.URL)
            }
            Section {
                TextField("Street", text: $profile.street)
                HStack {
                    TextField("Postal code", text: $profile.postalCode)
                        .frame(width: 120)
                    TextField("City", text: $profile.city)
                }
                TextField("Country", text: $profile.country)
            } header: {
                Text("Address")
            } footer: {
                Text("Appears in the sender line and footer of every invoice.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tax & bank

private struct TaxBankSettingsTab: View {
    @Binding var profile: CompanyProfile

    var body: some View {
        Form {
            Section {
                Toggle("Small business exemption", isOn: $profile.isVatExempt)
                if !profile.isVatExempt {
                    TextField("VAT ID", text: $profile.vatId)
                }
                TextField("Tax number", text: $profile.taxNumber)
                TextField("Company registry", text: $profile.companyRegistry)
            } header: {
                Text("Tax")
            } footer: {
                Text(profile.isVatExempt
                     ? "Kleinunternehmerregelung §19 UStG. No VAT is added and invoices carry the exemption notice."
                     : "At least one of VAT ID or tax number must appear on your invoices.")
            }

            Section {
                TextField("Account holder", text: $profile.accountHolder)
                TextField("IBAN", text: $profile.iban)
                    .monospacedDigit()
                TextField("BIC", text: $profile.bic)
                TextField("Bank name", text: $profile.bankName)
            } header: {
                Text("Bank account")
            } footer: {
                Text("Printed on every invoice so clients know where to pay.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Branding

private struct BrandingSettingsTab: View {
    @Binding var profile: CompanyProfile
    @Environment(\.themeColors) private var colors

    private var presets: [(name: String, hex: String)] { Array(BrandColors.presets.prefix(8)) }

    private var isPresetSelected: Bool {
        presets.contains { $0.hex.uppercased() == profile.brandColorHex.uppercased() }
    }

    var body: some View {
        HStack(spacing: 0) {
            Form {
                Section("Logo") {
                    LogoPicker(logoData: $profile.logoData)
                }
                Section {
                    HStack(spacing: Spacing.s) {
                        ForEach(presets, id: \.hex) { preset in
                            let color = Color(hex: preset.hex) ?? .blue
                            let selected = preset.hex.uppercased() == profile.brandColorHex.uppercased()
                            Button {
                                profile.brandColorHex = preset.hex
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if selected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                            .accessibilityLabel(preset.name)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                        ColorPicker("Custom color", selection: Binding(
                            get: { Color(hex: profile.brandColorHex) ?? .blue },
                            set: { profile.brandColorHex = $0.toHex() }
                        ))
                        .labelsHidden()
                        .frame(width: 26, height: 26)
                        .overlay {
                            if !isPresetSelected {
                                Circle().strokeBorder(colors.accent, lineWidth: 2).frame(width: 32, height: 32)
                            }
                        }
                        .help("Custom color")
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text("Brand color")
                } footer: {
                    Text("Used for headings and rules on the PDF.")
                }
            }
            .formStyle(.grouped)
            .frame(width: 380)

            Divider()

            VStack {
                InvoicePaper(invoice: Self.sampleInvoice, client: Self.sampleClient, profile: profile, width: 220)
                Text("Live preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Spacing.l)
            .background(.quaternary.opacity(0.35))
        }
    }

    static let sampleClient: Client = {
        var c = Client()
        c.name = "Acme GmbH"
        c.street = "Musterstraße 1"
        c.postalCode = "10115"
        c.city = "Berlin"
        return c
    }()

    static let sampleInvoice: Invoice = {
        var inv = Invoice(clientId: sampleClient.id)
        inv.invoiceNumber = "INV-2026-0042"
        inv.lineItems = [
            LineItem(description: "Design workshop", quantity: 1, unitPrice: 1800, vatRate: 19),
            LineItem(description: "Revisions", quantity: 6, unitPrice: 95, vatRate: 19),
        ]
        return inv
    }()
}

// MARK: - Templates

private struct TemplatesSettingsTab: View {
    @Binding var profile: CompanyProfile
    @State private var language: PDFTemplateLanguage = .german

    private var footer: Binding<String> {
        language == .german ? $profile.pdfFooterTemplateGerman : $profile.pdfFooterTemplateEnglish
    }
    private var closing: Binding<String> {
        language == .german ? $profile.pdfClosingTemplateGerman : $profile.pdfClosingTemplateEnglish
    }
    private var notes: Binding<String> {
        language == .german ? $profile.pdfNotesTemplateGerman : $profile.pdfNotesTemplateEnglish
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $language) {
                    Text("Deutsch").tag(PDFTemplateLanguage.german)
                    Text("English").tag(PDFTemplateLanguage.english)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } footer: {
                Text("Templates fill in automatically from the invoice. Click a placeholder to insert it.")
            }

            TemplateFieldSection(title: "Footer", description: "Shown at the bottom of every page.", text: footer)
            TemplateFieldSection(title: "Closing message", description: "Shown after the totals.", text: closing)
            TemplateFieldSection(title: "Notes", description: "Optional terms shown above the bank details. Leave empty to hide.", text: notes)

            Section {
                Button("Reset \(language == .german ? "German" : "English") templates to defaults") {
                    if language == .german {
                        profile.pdfFooterTemplateGerman = PDFTemplateLanguage.german.defaultFooter
                        profile.pdfClosingTemplateGerman = PDFTemplateLanguage.german.defaultClosing
                        profile.pdfNotesTemplateGerman = ""
                    } else {
                        profile.pdfFooterTemplateEnglish = PDFTemplateLanguage.english.defaultFooter
                        profile.pdfClosingTemplateEnglish = PDFTemplateLanguage.english.defaultClosing
                        profile.pdfNotesTemplateEnglish = ""
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct TemplateFieldSection: View {
    let title: String
    let description: String
    @Binding var text: String

    private let placeholders: [(label: String, value: String)] = [
        ("Invoice no.", "{invoiceNumber}"),
        ("Amount", "{totalAmount}"),
        ("Due date", "{dueDate}"),
        ("Company", "{companyName}"),
        ("Owner", "{ownerName}"),
        ("Client", "{clientName}"),
        ("Account holder", "{accountHolder}"),
        ("IBAN", "{iban}"),
        ("BIC", "{bic}"),
        ("Date", "{date}"),
        ("Payment terms", "{paymentTerms}"),
        ("VAT ID", "{vatId}"),
        ("Tax number", "{taxNumber}"),
    ]

    var body: some View {
        Section {
            TextField(title, text: $text, axis: .vertical)
                .lineLimit(2...6)
                .labelsHidden()
                .onChange(of: text) { _, newValue in
                    let cleaned = TemplatePlaceholderCleaner.clean(newValue)
                    if cleaned != newValue {
                        DispatchQueue.main.async { text = cleaned }
                    }
                }
            SimpleFlowLayout(spacing: 6) {
                ForEach(placeholders, id: \.value) { placeholder in
                    Button(placeholder.label) { text += placeholder.value }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Insert \(placeholder.value)")
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(description)
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    var body: some View {
        Form {
            Section {
                ThemePicker(compact: false)
            } footer: {
                Text("Themes are JSON files. Edit or add your own in the themes folder.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sync & security

private struct SyncSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updaterManager = UpdaterManager.shared
    let storageSummary: String

    @State private var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingCloudKit = true
    @State private var confirmRestart = false
    @AppStorage("mira.deleteLegacyAfterMigration") private var deleteLegacyAfterMigration = false

    var body: some View {
        Form {
            Section("iCloud") {
                LabeledContent {
                    if isCheckingCloudKit {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(cloudKitStatusText)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } label: {
                    Label {
                        Text("Sync")
                    } icon: {
                        Image(systemName: cloudKitIcon)
                            .foregroundStyle(cloudKitColor)
                    }
                }
            }

            Section("Encryption") {
                Label {
                    Text(EncryptionService.shared.hasKey
                         ? "Sensitive fields are encrypted with AES-256. The key is stored in your iCloud Keychain."
                         : "An encryption key is created the first time you save.")
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Text(storageSummary)
                Toggle("Delete legacy files after migration", isOn: $deleteLegacyAfterMigration)
            } header: {
                Text("Storage")
            } footer: {
                Text("Removes the old JSON files once their contents are safely migrated.")
            }

            Section {
                Button("Restart onboarding…") { confirmRestart = true }
                Button("Check for updates…") { updaterManager.checkForUpdates() }
                    .disabled(!updaterManager.canCheckForUpdates)
            } header: {
                Text("Setup")
            } footer: {
                if let lastCheck = updaterManager.lastUpdateCheckDate {
                    Text("Version \(updaterManager.currentVersion). Last checked \(lastCheck, style: .relative) ago.")
                } else {
                    Text("Version \(updaterManager.currentVersion).")
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Restart onboarding?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart onboarding") { appState.hasCompletedOnboarding = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Walks through setup again with your current details filled in. Nothing is deleted.")
        }
        .task {
            cloudKitStatus = await DataContainer.checkCloudKitStatus()
            isCheckingCloudKit = false
        }
    }

    private var cloudKitIcon: String {
        switch cloudKitStatus {
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "icloud.slash"
        case .restricted: return "lock.icloud"
        default: return "icloud"
        }
    }

    private var cloudKitColor: Color {
        switch cloudKitStatus {
        case .available: return .green
        case .noAccount, .restricted: return .orange
        default: return .secondary
        }
    }

    private var cloudKitStatusText: String {
        switch cloudKitStatus {
        case .available: return "Connected. Your data syncs across your devices."
        case .noAccount: return "Not signed in to iCloud."
        case .restricted: return "iCloud access is restricted."
        case .temporarilyUnavailable: return "iCloud is temporarily unavailable."
        case .couldNotDetermine: return "Couldn't check iCloud status."
        @unknown default: return "Status unavailable."
        }
    }
}

// MARK: - Placeholder cleanup

/// Removes broken or partial `{placeholder}` fragments left behind while editing.
enum TemplatePlaceholderCleaner {
    static let validPlaceholders = [
        "{invoiceNumber}", "{totalAmount}", "{dueDate}", "{companyName}",
        "{ownerName}", "{clientName}", "{accountHolder}", "{iban}", "{bic}",
        "{date}", "{paymentTerms}", "{vatId}", "{taxNumber}", "{bankName}"
    ]

    static func clean(_ text: String) -> String {
        var result = text

        for placeholder in validPlaceholders {
            if result.contains(placeholder) { continue }
            for len in 2..<placeholder.count {
                let prefix = String(placeholder.prefix(len))
                if prefix.contains("{") && result.contains(prefix) {
                    result = result.replacingOccurrences(of: prefix, with: "")
                }
            }
            for len in 2..<placeholder.count {
                let suffix = String(placeholder.suffix(len))
                if suffix.contains("}") && result.contains(suffix) {
                    result = result.replacingOccurrences(of: suffix, with: "")
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: "\\{[^}]*\\}") {
            let range = NSRange(result.startIndex..., in: result)
            for match in regex.matches(in: result, range: range).reversed() {
                if let matchRange = Range(match.range, in: result),
                   !validPlaceholders.contains(String(result[matchRange])) {
                    result.removeSubrange(matchRange)
                }
            }
        }

        return result
    }
}

/// Wrapping row layout for placeholder chips.
struct SimpleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        // SwiftUI probes with nil/zero/infinite widths; treat anything that is
        // not a finite positive width as "one row" and report the real extent,
        // never infinity, or the layout blows up.
        let maxWidth: CGFloat = {
            if let w = proposal.width, w.isFinite, w > 0 { return w }
            return .infinity
        }()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }
        let width = maxWidth.isFinite ? maxWidth : usedWidth
        return (positions, CGSize(width: width, height: y + rowHeight))
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
