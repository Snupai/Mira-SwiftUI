import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var appearance = AppAppearance.shared
    @Environment(\.themeColors) var colors
    @State private var showingColorPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(colors.text)
                
                // Appearance Section
                SettingsSection(title: "Appearance", colors: colors) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Theme
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Theme")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.subtext)
                            
                            HStack(spacing: 8) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    HStack(spacing: 6) {
                                        Image(systemName: theme.icon)
                                            .font(.system(size: 12))
                                        Text(theme.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(appearance.theme == theme ? colors.accent : colors.surface1)
                                    .foregroundColor(appearance.theme == theme ? .white : colors.text)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { appearance.theme = theme }
                                }
                            }
                        }
                        
                        // Accent Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accent Color")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.subtext)
                            
                            HStack(spacing: 8) {
                                if appearance.theme == .catppuccin {
                                    ForEach(CatppuccinAccent.options.prefix(8), id: \.name) { option in
                                        ZStack {
                                            HStack(spacing: 0) {
                                                Rectangle().fill(option.latte)
                                                Rectangle().fill(option.mocha)
                                            }
                                        }
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(colors.text, lineWidth: appearance.catppuccinAccentName == option.name ? 2 : 0).padding(-2))
                                        .onTapGesture { appearance.catppuccinAccentName = option.name }
                                    }
                                } else {
                                    ForEach(BrandColors.presets.prefix(6), id: \.hex) { preset in
                                        Circle()
                                            .fill(Color(hex: preset.hex) ?? .blue)
                                            .frame(width: 28, height: 28)
                                            .overlay(Circle().stroke(colors.text, lineWidth: appearance.accentColorHex == preset.hex ? 2 : 0).padding(-2))
                                            .onTapGesture { appearance.accentColorHex = preset.hex }
                                    }
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { appearance.accentColor },
                                        set: { appearance.accentColorHex = $0.toHex() }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 28, height: 28)
                                }
                            }
                        }
                    }
                }
                
                // Company
                SettingsSection(title: "Company", colors: colors) {
                        VStack(spacing: 16) {
                            SettingsTextField(label: "Company Name", text: binding(\.companyName), colors: colors)
                            SettingsTextField(label: "Owner Name", text: binding(\.ownerName), colors: colors)
                            SettingsTextField(label: "Email", text: binding(\.email), colors: colors)
                            SettingsTextField(label: "Phone", text: binding(\.phone), colors: colors)
                            SettingsTextField(label: "Website", text: binding(\.website), colors: colors)
                        }
                    }
                    
                    // Address
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
                    
                    // Tax
                    SettingsSection(title: "Tax Information", colors: colors) {
                        VStack(spacing: 16) {
                            // VAT Exemption Toggle
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
                            
                            if !(appState.companyProfile?.isVatExempt ?? false) {
                                SettingsTextField(label: "VAT ID (USt-IdNr.)", text: binding(\.vatId), colors: colors)
                            }
                            SettingsTextField(label: "Tax Number", text: binding(\.taxNumber), colors: colors)
                        }
                    }
                    
                    // Bank
                    SettingsSection(title: "Bank Details", colors: colors) {
                        VStack(spacing: 16) {
                            SettingsTextField(label: "Account Holder", text: binding(\.accountHolder), colors: colors)
                            SettingsTextField(label: "IBAN", text: binding(\.iban), colors: colors)
                            SettingsTextField(label: "BIC", text: binding(\.bic), colors: colors)
                            SettingsTextField(label: "Bank Name", text: binding(\.bankName), colors: colors)
                        }
                    }
                    
                    // Email Templates (both languages)
                    SettingsSection(title: "Email Templates", colors: colors) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Customize templates for each language. When sending an invoice, you'll be asked which language to use.")
                                .font(.system(size: 12))
                                .foregroundColor(colors.subtext)
                            
                            // German Template
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("🇩🇪")
                                        .font(.system(size: 16))
                                    Text("German Template")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colors.text)
                                    Spacer()
                                    Button("Reset to Default") {
                                        appState.companyProfile?.emailTemplateGerman = CompanyProfile.germanEmailTemplate
                                        appState.saveCompanyProfile()
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.accent)
                                    .buttonStyle(.plain)
                                }
                                
                                EmailTemplateEditor(
                                    template: Binding(
                                        get: { appState.companyProfile?.emailTemplateGerman ?? CompanyProfile.germanEmailTemplate },
                                        set: {
                                            appState.companyProfile?.emailTemplateGerman = $0
                                            appState.saveCompanyProfile()
                                        }
                                    ),
                                    colors: colors
                                )
                            }
                            
                            Divider()
                                .background(colors.surface1)
                            
                            // English Template
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("🇬🇧")
                                        .font(.system(size: 16))
                                    Text("English Template")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colors.text)
                                    Spacer()
                                    Button("Reset to Default") {
                                        appState.companyProfile?.emailTemplateEnglish = CompanyProfile.englishEmailTemplate
                                        appState.saveCompanyProfile()
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.accent)
                                    .buttonStyle(.plain)
                                }
                                
                                EmailTemplateEditor(
                                    template: Binding(
                                        get: { appState.companyProfile?.emailTemplateEnglish ?? CompanyProfile.englishEmailTemplate },
                                        set: {
                                            appState.companyProfile?.emailTemplateEnglish = $0
                                            appState.saveCompanyProfile()
                                        }
                                    ),
                                    colors: colors
                                )
                            }
                        }
                    }
                    
                // PDF Templates
                SettingsSection(title: "PDF Templates", colors: colors) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Language toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Language")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.subtext)
                            
                            HStack(spacing: 12) {
                                ForEach(PDFTemplateLanguage.allCases, id: \.self) { lang in
                                    Button(action: {
                                        appState.companyProfile?.pdfTemplateLanguage = lang
                                        appState.companyProfile?.pdfFooterTemplate = lang.defaultFooter
                                        appState.companyProfile?.pdfClosingTemplate = lang.defaultClosing
                                        appState.saveCompanyProfile()
                                    }) {
                                        HStack(spacing: 8) {
                                            Text(lang.icon)
                                                .font(.system(size: 16))
                                            Text(lang.rawValue)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(appState.companyProfile?.pdfTemplateLanguage == lang ? colors.accent : colors.surface1)
                                        .foregroundColor(appState.companyProfile?.pdfTemplateLanguage == lang ? .white : colors.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Spacer()
                                
                                Text("Switching resets templates to defaults")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.subtext)
                            }
                        }
                        
                        Divider()
                            .background(colors.surface1)
                        
                        // Footer Template
                        PDFTemplateEditor(
                            title: "Footer",
                            description: "Shown at the bottom of every page",
                            template: Binding(
                                get: { appState.companyProfile?.pdfFooterTemplate ?? "" },
                                set: {
                                    appState.companyProfile?.pdfFooterTemplate = $0
                                    appState.saveCompanyProfile()
                                }
                            ),
                            colors: colors
                        )
                        
                        // Closing Message
                        PDFTemplateEditor(
                            title: "Closing Message",
                            description: "Shown after the totals section",
                            template: Binding(
                                get: { appState.companyProfile?.pdfClosingTemplate ?? "" },
                                set: {
                                    appState.companyProfile?.pdfClosingTemplate = $0
                                    appState.saveCompanyProfile()
                                }
                            ),
                            colors: colors
                        )
                        
                        // Notes Section
                        PDFTemplateEditor(
                            title: "Notes / Terms",
                            description: "Optional notes shown above bank details (leave empty to hide)",
                            template: Binding(
                                get: { appState.companyProfile?.pdfNotesTemplate ?? "" },
                                set: {
                                    appState.companyProfile?.pdfNotesTemplate = $0
                                    appState.saveCompanyProfile()
                                }
                            ),
                            colors: colors
                        )
                        
                        // Available variables help
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(TemplateVariables.availableVariables, id: \.key) { variable in
                                    HStack {
                                        Text(variable.key)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(colors.accent)
                                        Text("→")
                                            .foregroundColor(colors.subtext)
                                        Text(variable.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(colors.subtext)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Available Template Variables")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.accent)
                        }
                    }
                }
                    
                    // Danger Zone
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
                    
                // Invoice Defaults
                SettingsSection(title: "Invoice Defaults", colors: colors) {
                    VStack(spacing: 16) {
                        SettingsTextField(label: "Invoice Prefix", text: binding(\.invoiceNumberPrefix), colors: colors)
                        
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
                        
                        // Payment Terms
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
                }
            }
            .padding(32)
        }
        .background(colors.base)
    }
    
    func binding<T>(_ keyPath: WritableKeyPath<CompanyProfile, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { appState.companyProfile?[keyPath: keyPath] ?? CompanyProfile()[keyPath: keyPath] },
            set: { newValue in
                appState.companyProfile?[keyPath: keyPath] = newValue
                appState.saveCompanyProfile()
            }
        )
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppState())
    }
}
