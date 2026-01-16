import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    @Environment(\.themeColors) var colors
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Simple icon
            Image(systemName: "doc.text")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(colors.text.opacity(0.8))
                .padding(.bottom, 32)
            
            // Title
            Text("Invoice")
                .font(.system(size: 42, weight: .semibold, design: .default))
                .foregroundColor(colors.text)
                .padding(.bottom, 12)
            
            // Subtitle
            Text("Simple invoicing for freelancers")
                .font(.system(size: 17))
                .foregroundColor(colors.subtext)
            
            Spacer()
            Spacer()
            
            // Continue Button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(colors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.base)
    }
}

struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(onContinue: {})
    }
}
