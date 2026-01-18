import SwiftUI
import Sparkle

struct AboutView: View {
    @ObservedObject private var updaterManager = UpdaterManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appearance = AppAppearance.shared
    
    private var themeColors: ThemeColors {
        appearance.colors(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            
            // App Name & Version
            VStack(spacing: 4) {
                Text("Mira")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(themeColors.text)
                
                Text("Version \(updaterManager.currentVersion)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(themeColors.subtext)
            }
            
            // Tagline
            Text("Simple invoicing for freelancers & small businesses")
                .font(.subheadline)
                .foregroundColor(themeColors.subtext)
                .multilineTextAlignment(.center)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Update Section
            VStack(spacing: 8) {
                Button(action: {
                    updaterManager.checkForUpdates()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Check for Updates")
                    }
                    .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColors.accent)
                .disabled(!updaterManager.canCheckForUpdates)
                
                if let lastCheck = updaterManager.lastUpdateCheckDate {
                    Text("Last checked: \(lastCheck, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(themeColors.subtext)
                }
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Links
            HStack(spacing: 20) {
                Link(destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Source")
                    }
                    .font(.caption)
                }
                
                Link(destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI/issues")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug")
                        Text("Report Bug")
                    }
                    .font(.caption)
                }
                
                Link(destination: URL(string: "https://github.com/Snupai/Mira-SwiftUI/releases")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("Changelog")
                    }
                    .font(.caption)
                }
            }
            .foregroundColor(themeColors.accent)
            
            Spacer()
            
            // Copyright
            VStack(spacing: 2) {
                Text("Made with 💜 by Snupai")
                    .font(.caption)
                    .foregroundColor(themeColors.subtext)
                
                Text("© 2026 All rights reserved")
                    .font(.caption2)
                    .foregroundColor(themeColors.overlay0)
            }
        }
        .padding(30)
        .frame(width: 360, height: 480)
        .background(themeColors.base)
    }
}

// Command to show About window
struct AboutCommand: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Mira") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
                // Show our custom window instead
                AboutWindowController.shared.showWindow()
            }
        }
    }
}

// Window controller for About
class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?
    
    func showWindow() {
        if window == nil {
            let aboutView = AboutView()
            let hostingController = NSHostingController(rootView: aboutView)
            
            window = NSWindow(contentViewController: hostingController)
            window?.title = "About Mira"
            window?.styleMask = [.titled, .closable]
            window?.isReleasedWhenClosed = false
            window?.center()
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
