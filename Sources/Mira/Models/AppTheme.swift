import SwiftUI

enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case catppuccin = "Catppuccin"
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .catppuccin: return "cat.fill"
        }
    }
}

// Theme colors provider
struct ThemeColors {
    let base: Color
    let mantle: Color
    let crust: Color
    let surface0: Color
    let surface1: Color
    let surface2: Color
    let overlay0: Color
    let text: Color
    let subtext: Color
    let accent: Color
    /// True when the palette resolves to macOS semantic colors. The content
    /// layer then leaves window backgrounds alone so Liquid Glass chrome shows
    /// the real desktop through it; custom palettes paint their own base.
    var isSystem: Bool = false
    
    static let fallback = ThemeColors(
        base: Color(nsColor: .windowBackgroundColor),
        mantle: Color(nsColor: .controlBackgroundColor),
        crust: Color(nsColor: .separatorColor),
        surface0: Color.secondary.opacity(0.08),
        surface1: Color.secondary.opacity(0.12),
        surface2: Color.secondary.opacity(0.16),
        overlay0: Color.secondary.opacity(0.3),
        text: Color.primary,
        subtext: Color.secondary,
        accent: .accentColor,
        isSystem: true
    )
}

// Environment key for theme colors
struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.fallback
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - Window roots

/// Installs the active theme at a window root: the resolved palette goes into
/// the environment, the accent becomes the tint, and custom palettes paint
/// their base color behind the content. Observes `ThemeManager`, so every
/// root re-renders the moment the theme or accent changes.
///
/// Apply this to every window and sheet root. Secondary windows (Settings,
/// About) and sheets are separate windows and inherit nothing from the main
/// one, which is how pages ended up half-themed.
struct ThemedRoot: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let colors = themeManager.colors(for: colorScheme)
        content
            .environment(\.themeColors, colors)
            .tint(colors.accent)
            .background {
                // System palettes leave the window alone so Liquid Glass chrome
                // shows the desktop through it.
                if !colors.isSystem {
                    colors.base.ignoresSafeArea()
                }
            }
    }
}

extension View {
    /// Theme this view as a window or sheet root. See `ThemedRoot`.
    func themed() -> some View {
        modifier(ThemedRoot())
    }
}
