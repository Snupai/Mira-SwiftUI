import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @Query private var sdProfiles: [SDCompanyProfile]
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var companyProfile: CompanyProfile
    
    var colors: ThemeColors {
        themeManager.colors(for: colorScheme)
    }

    init() {
        // Initialize with empty profile, will be updated in onAppear if existing data exists
        _companyProfile = State(initialValue: CompanyProfile())
    }

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case appearance = 1
        case companyBasics = 2
        case companyAddress = 3
        case taxInfo = 4
        case bankDetails = 5
        case branding = 6
        case complete = 7
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress
            if currentStep.rawValue > 0 && currentStep.rawValue < 7 {
                ProgressView(value: Double(currentStep.rawValue), total: 6)
                    .tint(colors.accent)
                    .padding(.horizontal, 60)
                    .padding(.top, 20)
            }
            
            // Content
            Group {
                switch currentStep {
                case .welcome:
                    OnboardingWelcomeView(onContinue: nextStep)
                case .appearance:
                    OnboardingAppearanceView(onBack: previousStep, onContinue: nextStep)
                case .companyBasics:
                    OnboardingCompanyBasicsView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .companyAddress:
                    OnboardingAddressView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .taxInfo:
                    OnboardingTaxView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .bankDetails:
                    OnboardingBankView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .branding:
                    OnboardingBrandingView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .complete:
                    OnboardingCompleteView(profile: companyProfile, onFinish: finishOnboarding)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentStep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Pre-populate with existing data if restarting onboarding
            if let existingProfile = appState.companyProfile {
                companyProfile = existingProfile
            }
        }
    }
    
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
    
    func finishOnboarding() {
        print("🚀 finishOnboarding called")
        
        // Always save to legacy first (ensures it works)
        appState.companyProfile = companyProfile
        appState.saveCompanyProfile()
        print("✅ Saved to legacy JSON")
        
        // Also save to SwiftData (new system)
        do {
            if let existingProfile = sdProfiles.first {
                // Update existing profile
                updateSDProfile(existingProfile, from: companyProfile)
                print("📝 Updated existing SwiftData profile")
            } else {
                // Create new profile
                let sdProfile = SDCompanyProfile(from: companyProfile)
                modelContext.insert(sdProfile)
                print("📝 Created new SwiftData profile")
            }
            
            try modelContext.save()
            print("✅ Saved to SwiftData")
        } catch {
            print("⚠️ SwiftData save failed: \(error)")
        }
        
        appState.hasCompletedOnboarding = true
        print("✅ Onboarding complete!")
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

struct OnboardingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingContainerView()
            .environmentObject(AppState())
    }
}
