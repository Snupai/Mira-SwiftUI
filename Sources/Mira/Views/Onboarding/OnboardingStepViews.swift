import SwiftUI

// MARK: - Appearance View

struct OnboardingAppearanceView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            title: "Appearance",
            subtitle: "Choose your theme",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            VStack(alignment: .leading, spacing: 24) {
                ThemePicker(compact: false)
                
                // Live Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    OnboardingThemePreview()
                }
            }
        }
    }
}

// Live preview of the selected theme
struct OnboardingThemePreview: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var colors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar preview
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.surface1)
                    .frame(width: 60, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.accent)
                    .frame(width: 50, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.surface1)
                    .frame(width: 55, height: 8)
            }
            .padding(12)
            .frame(width: 90)
            .background(colors.mantle)
            
            // Content preview
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.text)
                    .frame(width: 80, height: 10)
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.subtext)
                    .frame(width: 120, height: 6)
                
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.accent)
                        .frame(width: 50, height: 20)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.surface1)
                        .frame(width: 50, height: 20)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.base)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.crust, lineWidth: 1)
        )
    }
}

// MARK: - Minimal Form Field

struct MinimalFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    var isFocused: FocusState<Bool>.Binding? = nil
    var onSubmit: (() -> Void)? = nil
    @Environment(\.themeColors) var colors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.subtext)
                if required {
                    Text("*")
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            let textField = TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { onSubmit?() }
            
            if let isFocused = isFocused {
                textField.focused(isFocused)
            } else {
                textField
            }
        }
    }
}

/// Form field with explicit focus binding for keyboard navigation
struct FocusableFormField<F: Hashable>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    var focusedField: FocusState<F?>.Binding
    let field: F
    var onSubmit: () -> Void
    @Environment(\.themeColors) var colors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.subtext)
                if required {
                    Text("*")
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused(focusedField, equals: field)
                .onSubmit(onSubmit)
        }
    }
}

// MARK: - Step Layout

struct OnboardingStepLayout<Content: View>: View {
    let title: String
    let subtitle: String
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    let continueEnabled: Bool
    var showKeyboardHints: Bool = true
    @ViewBuilder let content: () -> Content
    @Environment(\.themeColors) var colors
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(colors.text)
                        HStack(spacing: 8) {
                            Text(subtitle)
                                .font(.system(size: 15))
                                .foregroundColor(colors.subtext)
                            Spacer()
                            // Keyboard hints (hidden for text editor steps)
                            if showKeyboardHints {
                                HStack(spacing: 4) {
                                    Text("Tab")
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(colors.surface1)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Text("to navigate")
                                        .font(.system(size: 10))
                                    Text("Enter")
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(colors.surface1)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Text("to continue")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(colors.subtext.opacity(0.7))
                            }
                        }
                    }
                    .padding(.top, 40)
                    
                    // Content
                    content()
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 100)
            }
            
            // Bottom buttons
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(colors.surface1)
                            .foregroundColor(colors.text)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 140)
                        .padding(.vertical, 12)
                        .background(continueEnabled ? colors.accent : colors.surface1)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!continueEnabled)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(colors.mantle)
            .focusSection()
        }
        .background(colors.base)
        // Keyboard shortcuts
        .background(
            Group {
                // Escape to go back
                if let onBack = onBack {
                    Button("") { onBack() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .opacity(0)
                }
            }
        )
    }
}

// MARK: - Company Basics

struct OnboardingCompanyBasicsView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void
    
    enum Field: Hashable { case companyName, ownerName, email, phone, website }
    @FocusState private var focusedField: Field?
    
    var canContinue: Bool {
        !profile.companyName.isEmpty && !profile.email.isEmpty
    }
    
    var body: some View {
        OnboardingStepLayout(
            title: "Your Business",
            subtitle: "Basic information about your company",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            VStack(spacing: 20) {
                FocusableFormField(label: "Company Name", placeholder: "Acme GmbH", text: $profile.companyName, required: true, focusedField: $focusedField, field: .companyName) { focusedField = .ownerName }
                FocusableFormField(label: "Your Name", placeholder: "Max Mustermann", text: $profile.ownerName, focusedField: $focusedField, field: .ownerName) { focusedField = .email }
                FocusableFormField(label: "Email", placeholder: "hello@example.com", text: $profile.email, required: true, focusedField: $focusedField, field: .email) { focusedField = .phone }
                FocusableFormField(label: "Phone", placeholder: "+49 123 456789", text: $profile.phone, focusedField: $focusedField, field: .phone) { focusedField = .website }
                FocusableFormField(label: "Website", placeholder: "https://example.com", text: $profile.website, focusedField: $focusedField, field: .website) { if canContinue { onContinue() } }
            }
        }
        .onAppear { focusedField = .companyName }
    }
}

// MARK: - Address

struct OnboardingAddressView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case street, postalCode, city, country }
    @FocusState private var focusedField: Field?

    var canContinue: Bool {
        !profile.street.isEmpty && !profile.city.isEmpty && !profile.postalCode.isEmpty
    }

    var body: some View {
        OnboardingStepLayout(
            title: "Address",
            subtitle: "Your business address for invoices",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            VStack(spacing: 20) {
                FocusableFormField(label: "Street", placeholder: "Musterstraße 123", text: $profile.street, required: true, focusedField: $focusedField, field: .street) { focusedField = .postalCode }
                HStack(spacing: 16) {
                    FocusableFormField(label: "Postal Code", placeholder: "12345", text: $profile.postalCode, required: true, focusedField: $focusedField, field: .postalCode) { focusedField = .city }
                        .frame(width: 120)
                    FocusableFormField(label: "City", placeholder: "Berlin", text: $profile.city, required: true, focusedField: $focusedField, field: .city) { focusedField = .country }
                }
                FocusableFormField(label: "Country", placeholder: "Germany", text: $profile.country, focusedField: $focusedField, field: .country) { if canContinue { onContinue() } }
            }
        }
        .onAppear { focusedField = .street }
    }
}

// MARK: - Tax

struct OnboardingTaxView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case vatExempt, vatId, taxNumber, companyRegistry }
    @FocusState private var focusedField: Field?

    var body: some View {
        OnboardingStepLayout(
            title: "Tax Information",
            subtitle: "Required for compliant invoices",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            VStack(spacing: 20) {
                // VAT Exemption Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Small Business Exemption")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Kleinunternehmerregelung §19 UStG")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $profile.isVatExempt)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .focused($focusedField, equals: .vatExempt)
                }
                .padding(16)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if !profile.isVatExempt {
                    FocusableFormField(label: "VAT ID (USt-IdNr.)", placeholder: "DE123456789", text: $profile.vatId, focusedField: $focusedField, field: .vatId) { focusedField = .taxNumber }
                }
                FocusableFormField(label: "Tax Number", placeholder: "12/345/67890", text: $profile.taxNumber, focusedField: $focusedField, field: .taxNumber) { focusedField = .companyRegistry }
                FocusableFormField(label: "Company Registry", placeholder: "HRB 12345, AG Berlin", text: $profile.companyRegistry, focusedField: $focusedField, field: .companyRegistry) { onContinue() }

                if profile.isVatExempt {
                    Text("No VAT will be charged. Invoice will include §19 UStG exemption notice.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                } else {
                    Text("You need at least a VAT ID or Tax Number on your invoices.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear { focusedField = profile.isVatExempt ? .taxNumber : .vatId }
    }
}

// MARK: - Bank

struct OnboardingBankView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case currency, accountHolder, iban, bic, bankName }
    @FocusState private var focusedField: Field?

    var canContinue: Bool { !profile.iban.isEmpty }

    var body: some View {
        OnboardingStepLayout(
            title: "Bank Details",
            subtitle: "How clients will pay you",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            VStack(spacing: 20) {
                // Base Currency
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Base Currency")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Picker("", selection: $profile.defaultCurrency) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .focused($focusedField, equals: .currency)
                }

                FocusableFormField(label: "Account Holder", placeholder: "Acme GmbH", text: $profile.accountHolder, focusedField: $focusedField, field: .accountHolder) { focusedField = .iban }
                FocusableFormField(label: "IBAN", placeholder: "DE89 3704 0044 0532 0130 00", text: $profile.iban, required: true, focusedField: $focusedField, field: .iban) { focusedField = .bic }
                FocusableFormField(label: "BIC", placeholder: "COBADEFFXXX", text: $profile.bic, focusedField: $focusedField, field: .bic) { focusedField = .bankName }
                FocusableFormField(label: "Bank Name", placeholder: "Commerzbank", text: $profile.bankName, focusedField: $focusedField, field: .bankName) { if canContinue { onContinue() } }
            }
        }
        .onAppear { focusedField = .currency }
    }
}

// MARK: - Branding

struct OnboardingBrandingView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.themeColors) var colors

    enum Field: Hashable { case brandColor, invoicePrefix, paymentTerms }
    @FocusState private var focusedField: Field?

    let paymentTerms = [7, 14, 30, 60]

    var body: some View {
        OnboardingStepLayout(
            title: "Customize",
            subtitle: "Brand your invoices",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            VStack(alignment: .leading, spacing: 28) {
                // Brand Color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Brand Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.subtext)

                    HStack(spacing: 10) {
                        ForEach(BrandColors.presets.prefix(6), id: \.hex) { preset in
                            Circle()
                                .fill(Color(hex: preset.hex) ?? .blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(colors.text, lineWidth: profile.brandColorHex == preset.hex ? 2 : 0)
                                        .padding(-3)
                                )
                                .onTapGesture { profile.brandColorHex = preset.hex }
                                .accessibilityAddTraits(profile.brandColorHex == preset.hex ? .isSelected : [])
                        }

                        ColorPicker("", selection: Binding(
                            get: { Color(hex: profile.brandColorHex) ?? .blue },
                            set: { profile.brandColorHex = $0.toHex() }
                        ))
                        .labelsHidden()
                        .frame(width: 32, height: 32)
                        .focused($focusedField, equals: .brandColor)
                    }
                }

                // Logo
                LogoPicker(logoData: $profile.logoData)

                Divider().background(colors.surface1).padding(.vertical, 8)

                // Invoice Prefix
                FocusableFormField(label: "Invoice Prefix", placeholder: "INV-", text: $profile.invoiceNumberPrefix, focusedField: $focusedField, field: .invoicePrefix) { focusedField = .paymentTerms }

                // Payment Terms
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment Terms")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.subtext)

                    HStack(spacing: 8) {
                        ForEach(paymentTerms, id: \.self) { days in
                            Text("\(days)d")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(profile.defaultPaymentTermsDays == days ? colors.accent : colors.surface1)
                                .foregroundColor(profile.defaultPaymentTermsDays == days ? .white : colors.text)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onTapGesture { profile.defaultPaymentTermsDays = days }
                                .accessibilityAddTraits(profile.defaultPaymentTermsDays == days ? .isSelected : [])
                        }
                    }
                }
            }
        }
        .onAppear { focusedField = .invoicePrefix }
    }
}

// MARK: - Email Template

struct OnboardingEmailTemplateView: View {
    @Binding var profile: CompanyProfile
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.themeColors) var colors

    enum Field: Hashable { case germanTemplate, englishTemplate }
    @FocusState private var focusedField: Field?

    var body: some View {
        OnboardingStepLayout(
            title: "Email Template",
            subtitle: "Customize your invoice emails",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true,
            showKeyboardHints: false
        ) {
            VStack(alignment: .leading, spacing: 20) {
                // Info text
                Text("You can customize email templates for both German and English. When sending an invoice, you'll choose which language to use.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.subtext)

                Divider()
                    .background(colors.surface1)

                // German Template
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🇩🇪")
                            .font(.system(size: 16))
                        Text("German Template")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.text)
                    }

                    EmailTemplateEditor(
                        template: $profile.emailTemplateGerman,
                        colors: colors,
                        defaultTemplate: CompanyProfile.germanEmailTemplate,
                        focusedField: $focusedField,
                        field: .germanTemplate
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
                    }

                    EmailTemplateEditor(
                        template: $profile.emailTemplateEnglish,
                        colors: colors,
                        defaultTemplate: CompanyProfile.englishEmailTemplate,
                        focusedField: $focusedField,
                        field: .englishTemplate
                    )
                }
            }
        }
        .onAppear { focusedField = .germanTemplate }
    }
}

struct EmailTemplateEditor<F: Hashable>: View {
    @Binding var template: String
    let colors: ThemeColors
    var defaultTemplate: String = CompanyProfile.germanEmailTemplate
    @State private var textView: NSTextView?
    var focusedField: FocusState<F?>.Binding? = nil
    var field: F? = nil

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
        VStack(alignment: .leading, spacing: 16) {
            // Custom text editor that exposes NSTextView
            Group {
                if let focusedField = focusedField, let field = field {
                    CursorAwareTextEditor(text: $template, textView: $textView, colors: colors)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused(focusedField, equals: field)
                } else {
                    CursorAwareTextEditor(text: $template, textView: $textView, colors: colors)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Placeholder buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Click to insert at cursor:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.subtext)

                FlowLayout(spacing: 6) {
                    ForEach(placeholders, id: \.value) { placeholder in
                        Text(placeholder.label)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(colors.accent.opacity(0.15))
                            .foregroundColor(colors.accent)
                            .clipShape(Capsule())
                            .onTapGesture {
                                insertAtCursor(placeholder.value)
                            }
                    }
                }
            }

            // Reset button
            Button(action: {
                template = defaultTemplate
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default")
                }
                .font(.system(size: 12))
                .foregroundColor(colors.subtext)
            }
            .buttonStyle(.plain)
        }
    }
    
    func insertAtCursor(_ text: String) {
        guard let textView = textView else {
            template += text
            return
        }
        
        let selectedRange = textView.selectedRange()
        if let textStorage = textView.textStorage {
            textStorage.replaceCharacters(in: selectedRange, with: text)
            // Move cursor after inserted text
            let newPosition = selectedRange.location + text.count
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            // Update binding
            template = textStorage.string
        }
        
        // Keep focus on text view
        textView.window?.makeFirstResponder(textView)
    }
}

#if os(macOS)
struct CursorAwareTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var textView: NSTextView?
    let colors: ThemeColors
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor(colors.text)
        textView.backgroundColor = NSColor(colors.surface1)
        textView.insertionPointColor = NSColor(colors.text)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(colors.surface1)
        
        DispatchQueue.main.async {
            self.textView = textView
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Try to restore cursor position
            let newLocation = min(selectedRange.location, text.count)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }
        
        textView.textColor = NSColor(colors.text)
        textView.backgroundColor = NSColor(colors.surface1)
        nsView.backgroundColor = NSColor(colors.surface1)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CursorAwareTextEditor
        
        // Known placeholders to treat as atomic blocks
        let placeholders = [
            "{invoiceNumber}",
            "{totalAmount}",
            "{dueDate}",
            "{companyName}",
            "{ownerName}",
            "{clientName}",
            "{accountHolder}",
            "{iban}",
            "{bic}"
        ]
        
        init(_ parent: CursorAwareTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        // Intercept text changes to handle placeholder deletion
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Only handle deletion (backspace/delete)
            guard let replacement = replacementString, replacement.isEmpty else {
                return true
            }
            
            let text = textView.string
            let nsText = text as NSString
            
            // Look for a placeholder that contains the deletion point
            for placeholder in placeholders {
                // Find all occurrences of this placeholder
                var searchRange = NSRange(location: 0, length: nsText.length)
                while searchRange.location < nsText.length {
                    let foundRange = nsText.range(of: placeholder, options: [], range: searchRange)
                    if foundRange.location == NSNotFound {
                        break
                    }
                    
                    let placeholderEnd = foundRange.location + foundRange.length
                    
                    // Check if deletion is happening inside this placeholder
                    if affectedCharRange.location >= foundRange.location && affectedCharRange.location < placeholderEnd {
                        // Delete the entire placeholder by directly modifying the text storage
                        if let textStorage = textView.textStorage {
                            textStorage.replaceCharacters(in: foundRange, with: "")
                            textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                            parent.text = textStorage.string
                        }
                        return false
                    }
                    
                    // Move search range forward
                    searchRange.location = placeholderEnd
                    searchRange.length = nsText.length - searchRange.location
                }
            }
            
            return true
        }
    }
}
#endif

// Simple flow layout for placeholder buttons
struct FlowLayout: Layout {
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

// MARK: - Complete

struct OnboardingCompleteView: View {
    let profile: CompanyProfile
    let onFinish: () -> Void
    @Environment(\.themeColors) var colors
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.green)
                .padding(.bottom, 32)
            
            Text("You're all set")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(colors.text)
                .padding(.bottom, 12)
            
            Text("Start creating invoices")
                .font(.system(size: 17))
                .foregroundColor(colors.subtext)
            
            Spacer()
            Spacer()
            
            Button(action: onFinish) {
                Text("Start")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(colors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
            .focusSection()
            .keyboardShortcut(.return, modifiers: [])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.base)
    }
}

struct OnboardingStepViews_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCompanyBasicsView(profile: .constant(CompanyProfile()), onBack: {}, onContinue: {})
    }
}
