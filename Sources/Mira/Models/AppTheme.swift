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
