import SwiftUI
import Sparkle

struct AboutView: View {
    @ObservedObject private var updaterManager = UpdaterManager.shared

    var body: some View {
        VStack(spacing: Spacing.l) {
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                    .padding(.top, Spacing.s)
            }

            VStack(spacing: Spacing.xs) {
                Text("Mira")
                    .font(.title.weight(.semibold))
                Text("Version \(updaterManager.currentVersion)")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text("Invoices for freelancers, done properly.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.s) {
                Button("Check for updates") {
                    updaterManager.checkForUpdates()
                }
                .buttonStyle(.glassProminent)
                .disabled(!updaterManager.canCheckForUpdates)

                if let lastCheck = updaterManager.lastUpdateCheckDate {
                    Text("Last checked \(lastCheck, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, Spacing.xs)

            HStack(spacing: Spacing.l) {
                Link("Source", destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI")!)
                Link("Report a bug", destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI/issues")!)
                Link("Release notes", destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI/releases")!)
            }
            .font(.callout)

            Spacer()

            Text("© 2026 Snupai. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.xl)
        .frame(width: 360, height: 440)
    }
}

/// Window controller for the custom About window.
class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func showWindow() {
        if window == nil {
            let hostingController = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "About Mira"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
