import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var appearance = AppAppearance.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var companyProfile = CompanyProfile()
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case appearance = 1
        case companyBasics = 2
        case companyAddress = 3
        case taxInfo = 4
        case bankDetails = 5
        case branding = 6
        case emailTemplate = 7
        case complete = 8
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress
            if currentStep.rawValue > 0 && currentStep.rawValue < 8 {
                ProgressView(value: Double(currentStep.rawValue), total: 7)
                    .tint(appearance.accentColor)
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
                case .emailTemplate:
                    OnboardingEmailTemplateView(profile: $companyProfile, onBack: previousStep, onContinue: nextStep)
                case .complete:
                    OnboardingCompleteView(profile: companyProfile, onFinish: finishOnboarding)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentStep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        appState.companyProfile = companyProfile
        appState.saveCompanyProfile()
        appState.hasCompletedOnboarding = true
    }
}

struct OnboardingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingContainerView()
            .environmentObject(AppState())
    }
}
