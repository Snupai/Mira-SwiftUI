import SwiftUI

/// First screen of setup: who Mira is for and what setup gets you.
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            appIcon
                .padding(.bottom, Spacing.xl)

            Text("Mira")
                .font(.largeTitle.weight(.semibold))
                .padding(.bottom, Spacing.xs)

            Text("Invoices for freelancers, done properly.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.l)

            Text("Set up your business details once. Every invoice you create is numbered, VAT-correct and ready to export as a PDF.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360, alignment: .leading)

            Spacer()

            HStack {
                Text("Takes about three minutes.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Set up Mira", action: onContinue)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.secondary)
                .frame(width: 96, height: 96)
        }
    }
}

/// Last screen of setup.
struct OnboardingCompleteView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .padding(.bottom, Spacing.xl)
                .accessibilityHidden(true)

            Text("You're set up")
                .font(.title.weight(.semibold))
                .padding(.bottom, Spacing.s)

            Text("Your details are saved and can be changed any time in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360, alignment: .leading)

            Spacer()

            HStack(spacing: Spacing.m) {
                Spacer()
                Button("Open Mira", action: onFinish)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                Button("Create your first invoice", action: onFinish)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview("Welcome") {
    OnboardingWelcomeView(onContinue: {})
        .frame(width: 460, height: 700)
}

#Preview("Done") {
    OnboardingCompleteView(onFinish: {})
        .frame(width: 460, height: 700)
}
