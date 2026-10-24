import SwiftUI
import SwiftData
import os

/// First-run setup. The form lives on the left; on the right a sample invoice
/// assembles itself from what the freelancer types, so the payoff of every
/// field is visible before Mira is ever used.
struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.themeColors) private var colors
    @Environment(\.modelContext) private var modelContext

    @Query private var sdProfiles: [SDCompanyProfile]

    @State private var currentStep: OnboardingStep = .welcome
    @State private var companyProfile = CompanyProfile()
    @State private var previewLanguage: PDFLanguage = .german
    @State private var didLoadExisting = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome, business, address, tax, bank, branding, appearance, done

        /// 1-based position for the progress header; nil on welcome/done.
        var progressIndex: Int? {
            switch self {
            case .welcome, .done: return nil
            default: return rawValue
            }
        }

        static let progressTotal = 6

        var paperFocus: InvoicePaper.Focus? {
            switch self {
            case .business: return .company
            case .address: return .address
            case .tax: return .tax
            case .bank: return .bank
            case .branding: return .branding
            default: return nil
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            leftPane
                .frame(width: 460)
            Divider()
            paperPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand {
            if currentStep != .welcome && currentStep != .done { previousStep() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotAdvanceOnboarding)) { _ in
            // Demo-only hook so snapshot runs can walk every step; fills sample data so the paper has content.
            guard DemoData.isEnabled else { return }
            if companyProfile.companyName.isEmpty {
                var sample = CompanyProfile()
                sample.companyName = "Studio Nord"; sample.ownerName = "Jana Weber"; sample.email = "hallo@studionord.de"
                sample.street = "Hafenstraße 12"; sample.postalCode = "20457"; sample.city = "Hamburg"
                sample.vatId = "DE123456789"; sample.iban = SampleData.placeholderIBAN; sample.bic = SampleData.placeholderBIC; sample.bankName = "Commerzbank"
                companyProfile = sample
            }
            nextStep()
        }
        .onAppear {
            guard !didLoadExisting else { return }
            didLoadExisting = true
            // Pre-populate when onboarding is restarted from Settings.
            if let existing = appState.companyProfile {
                companyProfile = existing
            }
        }
    }

    // MARK: Left pane

    @ViewBuilder
    private var leftPane: some View {
        Group {
            switch currentStep {
            case .welcome:
                OnboardingWelcomeView(onContinue: nextStep)
            case .business:
                OnboardingBusinessView(profile: $companyProfile, step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .address:
                OnboardingAddressView(profile: $companyProfile, step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .tax:
                OnboardingTaxView(profile: $companyProfile, step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .bank:
                OnboardingBankView(profile: $companyProfile, step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .branding:
                OnboardingBrandingView(profile: $companyProfile, step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .appearance:
                OnboardingAppearanceView(step: currentStep, onBack: previousStep, onContinue: nextStep)
            case .done:
                OnboardingCompleteView(onFinish: finishOnboarding)
            }
        }
        .id(currentStep)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
        .animation(.smooth(duration: 0.3), value: currentStep)
    }

    // MARK: Paper pane

    private var paperPane: some View {
        VStack(spacing: Spacing.l) {
            GeometryReader { geo in
                let available = min(geo.size.width - 80, (geo.size.height - 80) / 1.4142)
                let width = min(max(available, 280), 440)
                InvoicePaper(
                    invoice: sampleInvoice,
                    client: sampleClient,
                    profile: companyProfile,
                    language: previewLanguage,
                    width: width,
                    focus: currentStep.paperFocus
                )
                .animation(.smooth(duration: 0.35), value: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Picker("Preview language", selection: $previewLanguage) {
                Text("Deutsch").tag(PDFLanguage.german)
                Text("English").tag(PDFLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.top, Spacing.xl)
        .background(.quaternary.opacity(0.35))
        .ignoresSafeArea()
    }

    // MARK: Sample data

    private var sampleClient: Client {
        var client = Client()
        if previewLanguage == .german {
            client.name = "Beispiel GmbH"
            client.contactPerson = "Frau Müller"
            client.street = "Musterstraße 12"
            client.postalCode = "10115"
            client.city = "Berlin"
            client.country = "Deutschland"
        } else {
            client.name = "Example Ltd"
            client.contactPerson = "Ms Miller"
            client.street = "12 Sample Street"
            client.postalCode = "EC1A 1BB"
            client.city = "London"
            client.country = "United Kingdom"
        }
        return client
    }

    private var sampleInvoice: Invoice {
        var invoice = Invoice(clientId: sampleClient.id)
        invoice.invoiceNumber = companyProfile.generateInvoiceNumber()
        invoice.issueDate = Date()
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: companyProfile.defaultPaymentTermsDays, to: Date()) ?? Date()
        invoice.currency = companyProfile.defaultCurrency
        let vat = companyProfile.isVatExempt ? 0.0 : 19.0
        invoice.lineItems = [
            LineItem(description: previewLanguage == .german ? "Website-Redesign" : "Website redesign", quantity: 1, unitPrice: 2400, vatRate: vat),
            LineItem(description: previewLanguage == .german ? "Hosting-Einrichtung" : "Hosting setup", quantity: 2, unitPrice: 180, vatRate: vat),
        ]
        return invoice
    }

    // MARK: Navigation

    func nextStep() {
        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func previousStep() {
        if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    // MARK: Persistence

    func finishOnboarding() {
        Log.onboarding.notice("finishOnboarding called")

        // Save to legacy only if migrating existing data
        if MigrationService.shared.needsMigration {
            appState.companyProfile = companyProfile
            appState.saveCompanyProfile()
            Log.onboarding.info("Saved to legacy JSON")
        }

        // Save to SwiftData (new system)
        do {
            if let existingProfile = sdProfiles.first {
                updateSDProfile(existingProfile, from: companyProfile)
                Log.onboarding.info("Updated existing SwiftData profile")
            } else {
                let sdProfile = SDCompanyProfile(from: companyProfile)
                modelContext.insert(sdProfile)
                Log.onboarding.info("Created new SwiftData profile")
            }

            try modelContext.save()
            Log.onboarding.notice("Saved to SwiftData")
        } catch {
            Log.onboarding.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
        }

        appState.hasCompletedOnboarding = true
        Log.onboarding.notice("Onboarding complete")
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

        sdProfile.updatedAt = Date()
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
        .frame(width: 1100, height: 720)
}
