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
    @State private var profile: CompanyProfile?
    @State private var selectedCategory: SettingsCategory = .company
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings category", selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch selectedCategory {
                    case .company:
                        companySection
                        addressSection
                        taxSection
                        bankSection
                    case .invoices: invoiceDefaultsSection
                    case .pdf:
                        pdfTemplatesSection
                        exportSection
                    case .appearance: appearanceSection
                    case .sync:
                        syncStatusSection
                        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 20) {
                                Toggle("Delete legacy JSON after migration", isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "mira.deleteLegacyAfterMigration") },
                                    set: { UserDefaults.standard.set($0, forKey: "mira.deleteLegacyAfterMigration") }
                                ))
                                Text("Removes old JSON files after successful migration. Migration backups are retained.")
                                    .font(.caption).foregroundStyle(colors.subtext)
                                otherSection
                            }
                            .padding(.top, 12)
                        }
                    }
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .background(colors.base)
        .navigationTitle("Settings")
        .frame(minWidth: 540, minHeight: 500)
        .task { await checkCloudKitStatus() }
        .onAppear { loadProfile() }
        .onChange(of: sdProfiles.first?.updatedAt) { _, _ in
            if saveError == nil { loadProfile() }
        }
        .onChange(of: sdProfiles.count) { _, _ in
            if profile == nil { loadProfile() }
        }
        .alert("Settings could not be saved", isPresented: $showSaveError) {
            Button("Retry") { saveCompanyProfile() }
            Button("Keep Editing", role: .cancel) { }
        } message: { Text(saveError ?? "Please try again.") }
    }

    private func loadProfile() {
        profile = CompanyProfileStore.resolve(sdProfiles, legacy: appState.companyProfile)
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
        // Show SwiftData status if migration completed OR no legacy data exists
        if MigrationService.shared.useSwiftData {
            let profileCount = sdProfiles.count
            let syncStatus = cloudKitStatus == .available ? "CloudKit enabled" : "Local storage"
            return "SwiftData • \(profileCount > 0 ? "Profile loaded" : "No profile") • \(syncStatus)"
        }
        return "Legacy JSON storage • Migration available"
    }
    
    private func checkCloudKitStatus() async {
        cloudKitStatus = await DataContainer.checkCloudKitStatus()
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
                
                Divider().background(colors.surface1)
                
                // Brand Logo
                LogoPicker(logoData: Binding(
                    get: { profile?.logoData },
                    set: { newValue in
                        profile?.logoData = newValue
                        saveCompanyProfile()
                    }
                ))
                
                // Brand Color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brand Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.subtext)
                    
                    HStack(spacing: 10) {
                        ForEach(BrandColors.presets.prefix(6), id: \.hex) { preset in
                            Button {
                                profile?.brandColorHex = preset.hex
                                saveCompanyProfile()
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex) ?? .blue)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(colors.text, lineWidth: profile?.brandColorHex == preset.hex ? 2 : 0)
                                            .padding(-3)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Brand color: \(preset.name)")
                            .help(preset.name)
                        }
                        
                        ColorPicker("Custom brand color", selection: Binding(
                            get: { Color(hex: profile?.brandColorHex ?? "#0066CC") ?? .blue },
                            set: {
                                profile?.brandColorHex = $0.toHex()
                                saveCompanyProfile()
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                    }
                }
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
                if !(profile?.isVatExempt ?? false) {
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
                get: { profile?.isVatExempt ?? false },
                set: {
                    profile?.isVatExempt = $0
                    saveCompanyProfile()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .accessibilityLabel("Small business VAT exemption")
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
                    profile?.pdfFooterTemplateGerman = PDFTemplateLanguage.german.defaultFooter
                    profile?.pdfClosingTemplateGerman = PDFTemplateLanguage.german.defaultClosing
                    profile?.pdfNotesTemplateGerman = ""
                    saveCompanyProfile()
                }
                .font(.system(size: 11))
                .foregroundColor(colors.accent)
                .buttonStyle(.plain)
            }

            PDFTemplateEditorExpanded(
                title: "Footer",
                description: "Shown at the bottom of every page",
                template: Binding(
                    get: { profile?.pdfFooterTemplateGerman ?? PDFTemplateLanguage.german.defaultFooter },
                    set: { profile?.pdfFooterTemplateGerman = $0; saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Closing Message",
                description: "Shown after the totals section",
                template: Binding(
                    get: { profile?.pdfClosingTemplateGerman ?? PDFTemplateLanguage.german.defaultClosing },
                    set: { profile?.pdfClosingTemplateGerman = $0; saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Notes / Terms",
                description: "Optional notes shown above bank details (leave empty to hide)",
                template: Binding(
                    get: { profile?.pdfNotesTemplateGerman ?? "" },
                    set: { profile?.pdfNotesTemplateGerman = $0; saveCompanyProfile() }
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
                    profile?.pdfFooterTemplateEnglish = PDFTemplateLanguage.english.defaultFooter
                    profile?.pdfClosingTemplateEnglish = PDFTemplateLanguage.english.defaultClosing
                    profile?.pdfNotesTemplateEnglish = ""
                    saveCompanyProfile()
                }
                .font(.system(size: 11))
                .foregroundColor(colors.accent)
                .buttonStyle(.plain)
            }

            PDFTemplateEditorExpanded(
                title: "Footer",
                description: "Shown at the bottom of every page",
                template: Binding(
                    get: { profile?.pdfFooterTemplateEnglish ?? PDFTemplateLanguage.english.defaultFooter },
                    set: { profile?.pdfFooterTemplateEnglish = $0; saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Closing Message",
                description: "Shown after the totals section",
                template: Binding(
                    get: { profile?.pdfClosingTemplateEnglish ?? PDFTemplateLanguage.english.defaultClosing },
                    set: { profile?.pdfClosingTemplateEnglish = $0; saveCompanyProfile() }
                ),
                colors: colors
            )

            PDFTemplateEditorExpanded(
                title: "Notes / Terms",
                description: "Optional notes shown above bank details (leave empty to hide)",
                template: Binding(
                    get: { profile?.pdfNotesTemplateEnglish ?? "" },
                    set: { profile?.pdfNotesTemplateEnglish = $0; saveCompanyProfile() }
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

                Picker("Default Currency", selection: binding(\.defaultCurrency)) {
                    ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                HStack {
                    Text("Default VAT (%)")
                    TextField("VAT rate", value: binding(\.defaultVatRate), format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 90)
                        .accessibilityLabel("Default VAT percentage")
                }
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
                    if let num = profile?.nextInvoiceNumber, num > 1 {
                        profile?.nextInvoiceNumber = num - 1
                        saveCompanyProfile()
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                        .background(colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease next invoice number")

                Text("\(profile?.nextInvoiceNumber ?? 1)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(colors.text)
                    .frame(width: 50)

                Button(action: {
                    profile?.nextInvoiceNumber += 1
                    saveCompanyProfile()
                }) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                        .background(colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase next invoice number")
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
                    Button("\(days) days") {
                        profile?.defaultPaymentTermsDays = days
                        saveCompanyProfile()
                    }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(profile?.defaultPaymentTermsDays == days ? colors.accent : colors.surface1)
                        .foregroundColor(profile?.defaultPaymentTermsDays == days ? .white : colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                }
            }
        }
    }

    // MARK: - Export Section
    private var exportSection: some View {
        SettingsSection(title: "Export", colors: colors) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Export Location")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.subtext)
                
                HStack(spacing: 12) {
                    Text(exportPathDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(colors.surface0)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button(action: chooseExportFolder) {
                        Text("Choose...")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    
                    if !(profile?.defaultExportPath.isEmpty ?? true) {
                        Button(action: {
                            profile?.defaultExportPath = ""
                            saveCompanyProfile()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(colors.subtext)
                        }
                        .buttonStyle(.plain)
                        .help("Clear default location (will ask each time)")
                    }
                }
                
                Text("Leave empty to choose location each time you export")
                    .font(.system(size: 11))
                    .foregroundColor(colors.subtext)
            }
        }
    }
    
    private var exportPathDisplay: String {
        guard let path = profile?.defaultExportPath, !path.isEmpty else {
            return "Ask each time..."
        }
        return (path as NSString).lastPathComponent
    }
    
    private func chooseExportFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose default folder for PDF exports"
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            profile?.defaultExportPath = url.path
            saveCompanyProfile()
        }
        #endif
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
        MigrationService.shared.useSwiftData
    }
    
    func binding<T>(_ keyPath: WritableKeyPath<CompanyProfile, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { profile?[keyPath: keyPath] ?? CompanyProfile()[keyPath: keyPath] },
            set: { newValue in
                profile?[keyPath: keyPath] = newValue
                saveCompanyProfile()
            }
        )
    }
    
    private func saveCompanyProfile() {
        guard let profile else { return }
        do {
            try CompanyProfileStore.save(profile, profiles: sdProfiles, context: modelContext, appState: appState)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
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
            TextField(label, text: $text)
                .accessibilityLabel(label)
                .miraInput(colors: colors)
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


private enum SettingsCategory: String, CaseIterable, Identifiable {
    case company = "Company"
    case invoices = "Invoices"
    case pdf = "PDF & Export"
    case appearance = "Appearance"
    case sync = "Sync"
    var id: String { rawValue }
}
