import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var appearance = AppAppearance.shared
    @Environment(\.themeColors) var colors
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sdProfiles: [SDCompanyProfile]
    
    @State private var showingColorPicker = false
    @State private var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingCloudKit = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(colors.text)

                syncStatusSection
                appearanceSection
                companySection
                addressSection
                taxSection
                bankSection
                pdfTemplatesSection
                invoiceDefaultsSection
                otherSection
            }
            .padding(32)
        }
        .background(colors.base)
        .task {
            await checkCloudKitStatus()
        }
    }
    
    // MARK: - Sync Status Section
    private var syncStatusSection: some View {
        SettingsSection(title: "Sync & Security", colors: colors) {
            VStack(alignment: .leading, spacing: 16) {
                // CloudKit Status
                HStack {
                    Image(systemName: cloudKitIcon)
                        .foregroundColor(cloudKitColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Sync")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.text)
                        Text(cloudKitStatusText)
                            .font(.system(size: 11))
                            .foregroundColor(colors.subtext)
                    }
                    Spacer()
                    if isCheckingCloudKit {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Divider().background(colors.surface1)
                
                // Encryption Status
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Encryption")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.text)
                        Text(encryptionStatusText)
                            .font(.system(size: 11))
                            .foregroundColor(colors.subtext)
                    }
                    Spacer()
                }
                
                Divider().background(colors.surface1)
                
                // Storage Info
                HStack {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .foregroundColor(colors.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Storage")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.text)
                        Text(storageStatusText)
                            .font(.system(size: 11))
                            .foregroundColor(colors.subtext)
                    }
                    Spacer()
                }
                
                Divider().background(colors.surface1)
                
                // Delete legacy JSON after migration
                Toggle(isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "mira.deleteLegacyAfterMigration") },
                    set: { UserDefaults.standard.set($0, forKey: "mira.deleteLegacyAfterMigration") }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Legacy JSON After Migration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.text)
                        Text("Removes old JSON files after successful migration")
                            .font(.system(size: 11))
                            .foregroundColor(colors.subtext)
                    }
                }
                .toggleStyle(.switch)
            }
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
        default: return colors.subtext
        }
    }
    
    private var cloudKitStatusText: String {
        switch cloudKitStatus {
        case .available: return "Connected - Your data syncs across devices"
        case .noAccount: return "Not signed in to iCloud"
        case .restricted: return "iCloud access is restricted"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        case .couldNotDetermine: return "Could not check iCloud status"
        @unknown default: return "Status unavailable"
        }
    }
    
    private var encryptionStatusText: String {
        if EncryptionService.shared.hasKey {
            return "AES-256 encryption active • Key synced via iCloud Keychain"
        }
        return "Encryption key will be created on first use"
    }
    
    private var storageStatusText: String {
        if MigrationService.shared.migrationStatus == .completed {
            let profileCount = (try? sdProfiles.count) ?? 0
            let syncStatus = cloudKitStatus == .available ? "CloudKit enabled" : "Local storage"
            return "SwiftData • \(profileCount > 0 ? "Profile loaded" : "No profile") • \(syncStatus)"
        }
        return "Legacy JSON storage • Migration available"
    }
    
    private func checkCloudKitStatus() async {
        do {
            cloudKitStatus = await DataContainer.checkCloudKitStatus()
        } catch {
            print("⚠️ CloudKit status check error: \(error)")
            cloudKitStatus = .couldNotDetermine
        }
        isCheckingCloudKit = false
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        SettingsSection(title: "Appearance", colors: colors) {
            ThemePicker(compact: true)
        }
    }

    // MARK: - Company Section
    private var companySection: some View {
        SettingsSection(title: "Company", colors: colors) {
            VStack(spacing: 16) {
                SettingsTextField(label: "Company Name", text: binding(\.companyName), colors: colors)
                SettingsTextField(label: "Owner Name", text: binding(\.ownerName), colors: colors)
                SettingsTextField(label: "Email", text: binding(\.email), colors: colors)
                SettingsTextField(label: "Phone", text: binding(\.phone), colors: colors)
                SettingsTextField(label: "Website", text: binding(\.website), colors: colors)
            }
        }
    }

    // MARK: - Address Section
    private var addressSection: some View {
        SettingsSection(title: "Address", colors: colors) {
            VStack(spacing: 16) {
                SettingsTextField(label: "Street", text: binding(\.street), colors: colors)
                HStack(spacing: 16) {
                    SettingsTextField(label: "Postal Code", text: binding(\.postalCode), colors: colors)
                        .frame(width: 120)
                    SettingsTextField(label: "City", text: binding(\.city), colors: colors)
                }
                SettingsTextField(label: "Country", text: binding(\.country), colors: colors)
            }
        }
    }

    // MARK: - Tax Section
    private var taxSection: some View {
        SettingsSection(title: "Tax Information", colors: colors) {
            VStack(spacing: 16) {
                vatExemptionToggle
                if !(appState.companyProfile?.isVatExempt ?? false) {
                    SettingsTextField(label: "VAT ID (USt-IdNr.)", text: binding(\.vatId), colors: colors)
                }
                SettingsTextField(label: "Tax Number", text: binding(\.taxNumber), colors: colors)
            }
        }
    }

    private var vatExemptionToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Small Business Exemption")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.text)
                Text("Kleinunternehmerregelung §19 UStG - No VAT on invoices")
                    .font(.system(size: 11))
                    .foregroundColor(colors.subtext)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { appState.companyProfile?.isVatExempt ?? false },
                set: {
                    appState.companyProfile?.isVatExempt = $0
                    appState.saveCompanyProfile()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    // MARK: - Bank Section
    private var bankSection: some View {
        SettingsSection(title: "Bank Details", colors: colors) {
            VStack(spacing: 16) {
                SettingsTextField(label: "Account Holder", text: binding(\.accountHolder), colors: colors)
                SettingsTextField(label: "IBAN", text: binding(\.iban), colors: colors)
                SettingsTextField(label: "BIC", text: binding(\.bic), colors: colors)
                SettingsTextField(label: "Bank Name", text: binding(\.bankName), colors: colors)
            }
        }
    }

    // MARK: - PDF Templates Section
    private var pdfTemplatesSection: some View {
        SettingsSection(title: "PDF Templates", colors: colors) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Customize PDF templates for each language. Templates are used when generating invoice PDFs.")
                    .font(.system(size: 12))
                    .foregroundColor(colors.subtext)

                germanPdfTemplates
                Divider().background(colors.surface1)
                englishPdfTemplates
            }
        }
    }

    private var germanPdfTemplates: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🇩🇪")
                    .font(.system(size: 16))
                Text("German Templates")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                Spacer()
                Button("Reset All to Default") {
                    appState.companyProfile?.pdfFooterTemplateGerman = PDFTemplateLanguage.german.defaultFooter
                    appState.companyProfile?.pdfClosingTemplateGerman = PDFTemplateLanguage.german.defaultClosing
                    appState.companyProfile?.pdfNotesTemplateGerman = ""
                    appState.saveCompanyProfile()
                }
                .font(.system(size: 11))
                .foregroundColor(colors.accent)
                .buttonStyle(.plain)
            }

            PDFTemplateEditorExpanded(
                title: "Footer",
                description: "Shown at the bottom of every page",
                template: Binding(
                    get: { appState.companyProfile?.pdfFooterTemplateGerman ?? PDFTemplateLanguage.german.defaultFooter },
                    set: { appState.companyProfile?.pdfFooterTemplateGerman = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Closing Message",
                description: "Shown after the totals section",
                template: Binding(
                    get: { appState.companyProfile?.pdfClosingTemplateGerman ?? PDFTemplateLanguage.german.defaultClosing },
                    set: { appState.companyProfile?.pdfClosingTemplateGerman = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Notes / Terms",
                description: "Optional notes shown above bank details (leave empty to hide)",
                template: Binding(
                    get: { appState.companyProfile?.pdfNotesTemplateGerman ?? "" },
                    set: { appState.companyProfile?.pdfNotesTemplateGerman = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )
        }
    }

    private var englishPdfTemplates: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🇬🇧")
                    .font(.system(size: 16))
                Text("English Templates")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                Spacer()
                Button("Reset All to Default") {
                    appState.companyProfile?.pdfFooterTemplateEnglish = PDFTemplateLanguage.english.defaultFooter
                    appState.companyProfile?.pdfClosingTemplateEnglish = PDFTemplateLanguage.english.defaultClosing
                    appState.companyProfile?.pdfNotesTemplateEnglish = ""
                    appState.saveCompanyProfile()
                }
                .font(.system(size: 11))
                .foregroundColor(colors.accent)
                .buttonStyle(.plain)
            }

            PDFTemplateEditorExpanded(
                title: "Footer",
                description: "Shown at the bottom of every page",
                template: Binding(
                    get: { appState.companyProfile?.pdfFooterTemplateEnglish ?? PDFTemplateLanguage.english.defaultFooter },
                    set: { appState.companyProfile?.pdfFooterTemplateEnglish = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Closing Message",
                description: "Shown after the totals section",
                template: Binding(
                    get: { appState.companyProfile?.pdfClosingTemplateEnglish ?? PDFTemplateLanguage.english.defaultClosing },
                    set: { appState.companyProfile?.pdfClosingTemplateEnglish = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Notes / Terms",
                description: "Optional notes shown above bank details (leave empty to hide)",
                template: Binding(
                    get: { appState.companyProfile?.pdfNotesTemplateEnglish ?? "" },
                    set: { appState.companyProfile?.pdfNotesTemplateEnglish = $0; appState.saveCompanyProfile() }
                ),
                colors: colors
            )
        }
    }

    // MARK: - Invoice Defaults Section
    private var invoiceDefaultsSection: some View {
        SettingsSection(title: "Invoice Defaults", colors: colors) {
            VStack(spacing: 16) {
                SettingsTextField(label: "Invoice Prefix", text: binding(\.invoiceNumberPrefix), colors: colors)

                invoiceNumberStepper
                paymentTermsSelector
            }
        }
    }

    private var invoiceNumberStepper: some View {
        HStack {
            Text("Next Invoice Number")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.subtext)
            Spacer()
            HStack(spacing: 8) {
                Button(action: {
                    if let num = appState.companyProfile?.nextInvoiceNumber, num > 1 {
                        appState.companyProfile?.nextInvoiceNumber = num - 1
                        appState.saveCompanyProfile()
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                        .background(colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Text("\(appState.companyProfile?.nextInvoiceNumber ?? 1)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(colors.text)
                    .frame(width: 50)

                Button(action: {
                    appState.companyProfile?.nextInvoiceNumber += 1
                    appState.saveCompanyProfile()
                }) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                        .background(colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paymentTermsSelector: some View {
        HStack {
            Text("Payment Terms")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.subtext)
            Spacer()
            HStack(spacing: 6) {
                ForEach([7, 14, 30, 60], id: \.self) { days in
                    Text("\(days)d")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(appState.companyProfile?.defaultPaymentTermsDays == days ? colors.accent : colors.surface1)
                        .foregroundColor(appState.companyProfile?.defaultPaymentTermsDays == days ? .white : colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            appState.companyProfile?.defaultPaymentTermsDays = days
                            appState.saveCompanyProfile()
                        }
                }
            }
        }
    }

    // MARK: - Other Section
    private var otherSection: some View {
        SettingsSection(title: "Other", colors: colors) {
            Button(action: { appState.hasCompletedOnboarding = false }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart Onboarding")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper
    
    private var usesSwiftData: Bool {
        MigrationService.shared.migrationStatus == .completed
    }
    
    func binding<T>(_ keyPath: WritableKeyPath<CompanyProfile, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { appState.companyProfile?[keyPath: keyPath] ?? CompanyProfile()[keyPath: keyPath] },
            set: { newValue in
                appState.companyProfile?[keyPath: keyPath] = newValue
                saveCompanyProfile()
            }
        )
    }
    
    private func saveCompanyProfile() {
        // Save to SwiftData if migrated
        if usesSwiftData, let profile = appState.companyProfile {
            if let sdProfile = sdProfiles.first {
                updateSDProfile(sdProfile, from: profile)
                try? modelContext.save()
            }
        }
        // Save to legacy only when migrating old data
        appState.saveCompanyProfile()
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
        sdProfile.updatedAt = Date()
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let colors: ThemeColors
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.text)
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    let colors: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.subtext)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PDFTemplateEditor: View {
    let title: String
    let description: String
    @Binding var template: String
    let colors: ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(colors.subtext)
            }

            TextField("", text: $template)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PDFTemplateEditorExpanded: View {
    let title: String
    let description: String
    @Binding var template: String
    let colors: ThemeColors
    @State private var editorHeight: CGFloat = 100

    let placeholders: [(label: String, value: String)] = [
        ("Invoice #", "{invoiceNumber}"),
        ("Amount", "{totalAmount}"),
        ("Due Date", "{dueDate}"),
        ("Company", "{companyName}"),
        ("Owner", "{ownerName}"),
        ("Client", "{clientName}"),
        ("Account Holder", "{accountHolder}"),
        ("IBAN", "{iban}"),
        ("BIC", "{bic}"),
        ("Date", "{date}"),
        ("Payment Terms", "{paymentTerms}")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(colors.subtext)
            }

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $template)
                    .font(.system(size: 13))
                    .foregroundColor(colors.text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: editorHeight)
                    .background(colors.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: template) { _, newValue in
                        let cleaned = TemplatePlaceholderCleaner.clean(newValue)
                        if cleaned != newValue {
                            DispatchQueue.main.async { template = cleaned }
                        }
                    }

                // Resize handle
                ResizeHandle(height: $editorHeight, minHeight: 60, maxHeight: 300, colors: colors)
            }

            // Clickable placeholder buttons
            SimpleFlowLayout(spacing: 6) {
                ForEach(placeholders, id: \.value) { placeholder in
                    Button(action: {
                        template += placeholder.value
                    }) {
                        Text(placeholder.label)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colors.accent.opacity(0.15))
                            .foregroundColor(colors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SimpleEmailTemplateEditor: View {
    @Binding var template: String
    let colors: ThemeColors
    @State private var editorHeight: CGFloat = 180

    let placeholders: [(label: String, value: String)] = [
        ("Invoice #", "{invoiceNumber}"),
        ("Amount", "{totalAmount}"),
        ("Due Date", "{dueDate}"),
        ("Company", "{companyName}"),
        ("Owner", "{ownerName}"),
        ("Client", "{clientName}"),
        ("Account Holder", "{accountHolder}"),
        ("IBAN", "{iban}"),
        ("BIC", "{bic}")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Multi-line text editor with placeholder cleanup
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $template)
                    .font(.system(size: 13))
                    .foregroundColor(colors.text)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: editorHeight)
                    .background(colors.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: template) { _, newValue in
                        let cleaned = TemplatePlaceholderCleaner.clean(newValue)
                        if cleaned != newValue {
                            DispatchQueue.main.async { template = cleaned }
                        }
                    }

                // Resize handle
                ResizeHandle(height: $editorHeight, minHeight: 80, maxHeight: 400, colors: colors)
            }

            // Clickable placeholder buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Click to insert placeholder:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.subtext)

                SimpleFlowLayout(spacing: 6) {
                    ForEach(placeholders, id: \.value) { placeholder in
                        Button(action: {
                            template += placeholder.value
                        }) {
                            Text(placeholder.label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(colors.accent.opacity(0.15))
                                .foregroundColor(colors.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// Resize handle for text editors
struct ResizeHandle: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let colors: ThemeColors
    @State private var isDragging = false

    var body: some View {
        // Diagonal lines resize indicator
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10))
            .rotationEffect(.degrees(-45))
            .foregroundColor(isDragging ? colors.accent : colors.subtext.opacity(0.5))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height + value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .padding(4)
    }
}

// Helper to clean up broken/partial placeholders
enum TemplatePlaceholderCleaner {
    static let validPlaceholders = [
        "{invoiceNumber}", "{totalAmount}", "{dueDate}", "{companyName}",
        "{ownerName}", "{clientName}", "{accountHolder}", "{iban}", "{bic}",
        "{date}", "{paymentTerms}", "{vatId}", "{taxNumber}", "{bankName}"
    ]

    static func clean(_ text: String) -> String {
        var result = text

        // For each valid placeholder, if it's been partially deleted, remove the rest
        for placeholder in validPlaceholders {
            // If the full placeholder exists, leave it alone
            if result.contains(placeholder) { continue }

            // Check for any partial versions and remove them
            // Partials that start with { (e.g., "{taxNum", "{clientNa")
            for len in 2..<placeholder.count {
                let prefix = String(placeholder.prefix(len))
                if prefix.contains("{") && result.contains(prefix) {
                    result = result.replacingOccurrences(of: prefix, with: "")
                }
            }

            // Partials that end with } (e.g., "Number}", "me}")
            for len in 2..<placeholder.count {
                let suffix = String(placeholder.suffix(len))
                if suffix.contains("}") && result.contains(suffix) {
                    result = result.replacingOccurrences(of: suffix, with: "")
                }
            }
        }

        // Also clean up any orphaned braces
        // Remove {...} patterns that aren't valid placeholders
        if let regex = try? NSRegularExpression(pattern: "\\{[^}]*\\}") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let matchRange = Range(match.range, in: result) {
                    let found = String(result[matchRange])
                    if !validPlaceholders.contains(found) {
                        result.removeSubrange(matchRange)
                    }
                }
            }
        }

        return result
    }
}

struct SimpleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

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
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppState())
    }
}
