import SwiftUI

// MARK: - Step layout

/// Shared frame for every form step: progress, title, one sentence of help,
/// the fields, and a Back/Continue bar. Escape goes back (handled by the
/// container); Return is handled by the fields so the last one continues.
struct OnboardingStepLayout<Content: View>: View {
    let step: OnboardingContainerView.OnboardingStep
    let title: String
    let explanation: String
    let onBack: () -> Void
    let onContinue: () -> Void
    let continueEnabled: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let index = step.progressIndex {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Step \(index) of \(OnboardingContainerView.OnboardingStep.progressTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(index), total: Double(OnboardingContainerView.OnboardingStep.progressTotal))
                        .controlSize(.small)
                        .frame(width: 140)
                }
                .padding(.bottom, Spacing.xxl)
            }

            Text(title)
                .font(.title.weight(.semibold))
                .padding(.bottom, Spacing.s)

            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380, alignment: .leading)
                .padding(.bottom, Spacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    content()
                }
                .padding(.bottom, Spacing.l)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: Spacing.m)

            HStack(spacing: Spacing.m) {
                Text("Return to continue, Escape to go back")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Back", action: onBack)
                    .buttonStyle(.glass)
                Button("Continue", action: onContinue)
                    .buttonStyle(.glassProminent)
                    .disabled(!continueEnabled)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Field

/// Labelled text field with explicit focus so Return walks through the form.
struct OnboardingField<F: Hashable>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    var focusedField: FocusState<F?>.Binding
    let field: F
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 2) {
                Text(label)
                if required {
                    Text("*")
                        .foregroundStyle(.red)
                        .accessibilityLabel("required")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: field)
                .onSubmit(onSubmit)
        }
    }
}

// MARK: - Business

struct OnboardingBusinessView: View {
    @Binding var profile: CompanyProfile
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case companyName, ownerName, email, phone, website }
    @FocusState private var focus: Field?

    private var canContinue: Bool {
        !profile.companyName.trimmingCharacters(in: .whitespaces).isEmpty
            && !profile.email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Your business",
            explanation: "This is how you appear at the top of every invoice.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            OnboardingField(label: "Company name", placeholder: "Studio Nord", text: $profile.companyName, required: true, focusedField: $focus, field: .companyName) { focus = .ownerName }
            OnboardingField(label: "Your name", placeholder: "Jana Weber", text: $profile.ownerName, focusedField: $focus, field: .ownerName) { focus = .email }
            OnboardingField(label: "Email", placeholder: "hello@studionord.de", text: $profile.email, required: true, focusedField: $focus, field: .email) { focus = .phone }
            OnboardingField(label: "Phone", placeholder: "+49 40 123456", text: $profile.phone, focusedField: $focus, field: .phone) { focus = .website }
            OnboardingField(label: "Website", placeholder: "studionord.de", text: $profile.website, focusedField: $focus, field: .website) {
                if canContinue { onContinue() }
            }
        }
        .onAppear { focus = .companyName }
    }
}

// MARK: - Address

struct OnboardingAddressView: View {
    @Binding var profile: CompanyProfile
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case street, postalCode, city, country }
    @FocusState private var focus: Field?

    private var canContinue: Bool {
        !profile.street.trimmingCharacters(in: .whitespaces).isEmpty
            && !profile.postalCode.trimmingCharacters(in: .whitespaces).isEmpty
            && !profile.city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Your address",
            explanation: "A full postal address is required on German invoices.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            OnboardingField(label: "Street", placeholder: "Hafenstraße 12", text: $profile.street, required: true, focusedField: $focus, field: .street) { focus = .postalCode }
            HStack(alignment: .top, spacing: Spacing.m) {
                OnboardingField(label: "Postal code", placeholder: "20457", text: $profile.postalCode, required: true, focusedField: $focus, field: .postalCode) { focus = .city }
                    .frame(width: 120)
                OnboardingField(label: "City", placeholder: "Hamburg", text: $profile.city, required: true, focusedField: $focus, field: .city) { focus = .country }
            }
            OnboardingField(label: "Country", placeholder: "Germany", text: $profile.country, focusedField: $focus, field: .country) {
                if canContinue { onContinue() }
            }
        }
        .onAppear { focus = .street }
    }
}

// MARK: - Tax

struct OnboardingTaxView: View {
    @Binding var profile: CompanyProfile
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case vatId, taxNumber, companyRegistry }
    @FocusState private var focus: Field?

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Tax details",
            explanation: "German invoices must show your VAT ID or tax number. If you use the small business exemption, say so here.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle("I use the small business exemption (§19 UStG)", isOn: $profile.isVatExempt.animation(.smooth))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Text(profile.isVatExempt
                     ? "No VAT is added. Every invoice carries the §19 UStG notice."
                     : "VAT is added per line item, 19 % by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, Spacing.s)

            if !profile.isVatExempt {
                OnboardingField(label: "VAT ID", placeholder: "DE123456789", text: $profile.vatId, focusedField: $focus, field: .vatId) { focus = .taxNumber }
            }
            OnboardingField(label: "Tax number", placeholder: "12/345/67890", text: $profile.taxNumber, focusedField: $focus, field: .taxNumber) { focus = .companyRegistry }
            OnboardingField(label: "Company registry (optional)", placeholder: "HRB 12345, AG Hamburg", text: $profile.companyRegistry, focusedField: $focus, field: .companyRegistry) { onContinue() }
        }
        .onAppear { focus = profile.isVatExempt ? .taxNumber : .vatId }
    }
}

// MARK: - Bank

struct OnboardingBankView: View {
    @Binding var profile: CompanyProfile
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    enum Field: Hashable { case accountHolder, iban, bic, bankName }
    @FocusState private var focus: Field?

    private var canContinue: Bool { !profile.iban.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Bank account",
            explanation: "Printed on the invoice so clients know where to pay.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: canContinue
        ) {
            OnboardingField(label: "Account holder", placeholder: profile.companyName.isEmpty ? "Studio Nord" : profile.companyName, text: $profile.accountHolder, focusedField: $focus, field: .accountHolder) { focus = .iban }
            OnboardingField(label: "IBAN", placeholder: "DE89 3704 0044 0532 0130 00", text: $profile.iban, required: true, focusedField: $focus, field: .iban) { focus = .bic }
            OnboardingField(label: "BIC", placeholder: SampleData.placeholderBIC, text: $profile.bic, focusedField: $focus, field: .bic) { focus = .bankName }
            OnboardingField(label: "Bank name", placeholder: "Commerzbank", text: $profile.bankName, focusedField: $focus, field: .bankName) {
                if canContinue { onContinue() }
            }
        }
        .onAppear { focus = .accountHolder }
    }
}

// MARK: - Branding

struct OnboardingBrandingView: View {
    @Binding var profile: CompanyProfile
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.themeColors) private var colors

    enum Field: Hashable { case invoicePrefix }
    @FocusState private var focus: Field?

    private let paymentTerms = [7, 14, 30, 60]

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Invoice defaults",
            explanation: "Numbering, payment terms and the color your invoices use. All of this can change later.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Base currency")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("Base currency", selection: $profile.defaultCurrency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text("\(currency.symbol) \(currency.rawValue)").tag(currency)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Payment terms")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("Payment terms", selection: $profile.defaultPaymentTermsDays) {
                    ForEach(paymentTerms, id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                OnboardingField(label: "Invoice prefix", placeholder: "INV-", text: $profile.invoiceNumberPrefix, focusedField: $focus, field: .invoicePrefix) { onContinue() }
                Text("Your next invoice will be \(profile.generateInvoiceNumber()).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Brand color")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: Spacing.s) {
                    ForEach(BrandColors.presets.prefix(8), id: \.hex) { preset in
                        let color = Color(hex: preset.hex) ?? .blue
                        let selected = profile.brandColorHex.uppercased() == preset.hex.uppercased()
                        Button {
                            withAnimation(.snappy) { profile.brandColorHex = preset.hex }
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
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
                    .help("Custom color")
                }
            }

            LogoPicker(logoData: $profile.logoData)
        }
        .onAppear { focus = .invoicePrefix }
    }
}

// MARK: - Appearance

struct OnboardingAppearanceView: View {
    let step: OnboardingContainerView.OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            step: step,
            title: "Appearance",
            explanation: "Pick the look of Mira itself. This never affects your invoices.",
            onBack: onBack,
            onContinue: onContinue,
            continueEnabled: true
        ) {
            ThemePicker(compact: false)
        }
        .background {
            // Return continues here since there is no text field to own it.
            Button("", action: onContinue)
                .keyboardShortcut(.defaultAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Business") {
    OnboardingBusinessView(profile: .constant(CompanyProfile()), step: .business, onBack: {}, onContinue: {})
        .frame(width: 460, height: 700)
}
