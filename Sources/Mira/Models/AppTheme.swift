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
        accent: .purple
    )
    
    static func forTheme(_ theme: AppTheme, colorScheme: ColorScheme, accentName: String, customAccentHex: String) -> ThemeColors {
        // Delegate to ThemeManager for JSON-based themes
        return ThemeManager.shared.colors(for: colorScheme)
    }
    
    private static func systemColors(customAccentHex: String) -> ThemeColors {
        ThemeColors(
            base: Color(nsColor: .windowBackgroundColor),
            mantle: Color(nsColor: .controlBackgroundColor),
            crust: Color(nsColor: .separatorColor),
            surface0: Color.secondary.opacity(0.08),
            surface1: Color.secondary.opacity(0.12),
            surface2: Color.secondary.opacity(0.16),
            overlay0: Color.secondary.opacity(0.3),
            text: Color.primary,
            subtext: Color.secondary,
            accent: Color(hex: customAccentHex) ?? .blue
        )
    }
    
    private static func catppuccinMocha(accentName: String) -> ThemeColors {
        let accent = CatppuccinAccent.options.first { $0.name == accentName }?.mocha ?? CatppuccinMocha.mauve
        return ThemeColors(
            base: CatppuccinMocha.base,
            mantle: CatppuccinMocha.mantle,
            crust: CatppuccinMocha.crust,
            surface0: CatppuccinMocha.surface0,
            surface1: CatppuccinMocha.surface1,
            surface2: CatppuccinMocha.surface2,
            overlay0: CatppuccinMocha.overlay0,
            text: CatppuccinMocha.text,
            subtext: CatppuccinMocha.subtext0,
            accent: accent
        )
    }
    
    private static func catppuccinLatte(accentName: String) -> ThemeColors {
        let accent = CatppuccinAccent.options.first { $0.name == accentName }?.latte ?? CatppuccinLatte.mauve
        return ThemeColors(
            base: CatppuccinLatte.base,
            mantle: CatppuccinLatte.mantle,
            crust: CatppuccinLatte.crust,
            surface0: CatppuccinLatte.surface0,
            surface1: CatppuccinLatte.surface1,
            surface2: CatppuccinLatte.surface2,
            overlay0: CatppuccinLatte.overlay0,
            text: CatppuccinLatte.text,
            subtext: CatppuccinLatte.subtext0,
            accent: accent
        )
    }
}

// Catppuccin Mocha (Dark)
struct CatppuccinMocha {
    static let rosewater = Color(hex: "#f5e0dc")!
    static let flamingo = Color(hex: "#f2cdcd")!
    static let pink = Color(hex: "#f5c2e7")!
    static let mauve = Color(hex: "#cba6f7")!
    static let red = Color(hex: "#f38ba8")!
    static let maroon = Color(hex: "#eba0ac")!
    static let peach = Color(hex: "#fab387")!
    static let yellow = Color(hex: "#f9e2af")!
    static let green = Color(hex: "#a6e3a1")!
    static let teal = Color(hex: "#94e2d5")!
    static let sky = Color(hex: "#89dceb")!
    static let sapphire = Color(hex: "#74c7ec")!
    static let blue = Color(hex: "#89b4fa")!
    static let lavender = Color(hex: "#b4befe")!
    static let text = Color(hex: "#cdd6f4")!
    static let subtext1 = Color(hex: "#bac2de")!
    static let subtext0 = Color(hex: "#a6adc8")!
    static let overlay2 = Color(hex: "#9399b2")!
    static let overlay1 = Color(hex: "#7f849c")!
    static let overlay0 = Color(hex: "#6c7086")!
    static let surface2 = Color(hex: "#585b70")!
    static let surface1 = Color(hex: "#45475a")!
    static let surface0 = Color(hex: "#313244")!
    static let base = Color(hex: "#1e1e2e")!
    static let mantle = Color(hex: "#181825")!
    static let crust = Color(hex: "#11111b")!
}

// Catppuccin Latte (Light)
struct CatppuccinLatte {
    static let rosewater = Color(hex: "#dc8a78")!
    static let flamingo = Color(hex: "#dd7878")!
    static let pink = Color(hex: "#ea76cb")!
    static let mauve = Color(hex: "#8839ef")!
    static let red = Color(hex: "#d20f39")!
    static let maroon = Color(hex: "#e64553")!
    static let peach = Color(hex: "#fe640b")!
    static let yellow = Color(hex: "#df8e1d")!
    static let green = Color(hex: "#40a02b")!
    static let teal = Color(hex: "#179299")!
    static let sky = Color(hex: "#04a5e5")!
    static let sapphire = Color(hex: "#209fb5")!
    static let blue = Color(hex: "#1e66f5")!
    static let lavender = Color(hex: "#7287fd")!
    static let text = Color(hex: "#4c4f69")!
    static let subtext1 = Color(hex: "#5c5f77")!
    static let subtext0 = Color(hex: "#6c6f85")!
    static let overlay2 = Color(hex: "#7c7f93")!
    static let overlay1 = Color(hex: "#8c8fa1")!
    static let overlay0 = Color(hex: "#9ca0b0")!
    static let surface2 = Color(hex: "#acb0be")!
    static let surface1 = Color(hex: "#bcc0cc")!
    static let surface0 = Color(hex: "#ccd0da")!
    static let base = Color(hex: "#eff1f5")!
    static let mantle = Color(hex: "#e6e9ef")!
    static let crust = Color(hex: "#dce0e8")!
}

// Catppuccin accent options
struct CatppuccinAccent {
    let name: String
    let mocha: Color
    let latte: Color
    
    static let options: [CatppuccinAccent] = [
        CatppuccinAccent(name: "Mauve", mocha: CatppuccinMocha.mauve, latte: CatppuccinLatte.mauve),
        CatppuccinAccent(name: "Pink", mocha: CatppuccinMocha.pink, latte: CatppuccinLatte.pink),
        CatppuccinAccent(name: "Red", mocha: CatppuccinMocha.red, latte: CatppuccinLatte.red),
        CatppuccinAccent(name: "Peach", mocha: CatppuccinMocha.peach, latte: CatppuccinLatte.peach),
        CatppuccinAccent(name: "Yellow", mocha: CatppuccinMocha.yellow, latte: CatppuccinLatte.yellow),
        CatppuccinAccent(name: "Green", mocha: CatppuccinMocha.green, latte: CatppuccinLatte.green),
        CatppuccinAccent(name: "Teal", mocha: CatppuccinMocha.teal, latte: CatppuccinLatte.teal),
        CatppuccinAccent(name: "Blue", mocha: CatppuccinMocha.blue, latte: CatppuccinLatte.blue),
        CatppuccinAccent(name: "Lavender", mocha: CatppuccinMocha.lavender, latte: CatppuccinLatte.lavender),
        CatppuccinAccent(name: "Sky", mocha: CatppuccinMocha.sky, latte: CatppuccinLatte.sky),
    ]
}

// App appearance settings
class AppAppearance: ObservableObject {
    static let shared = AppAppearance()
    
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }
    
    @Published var accentColorHex: String {
        didSet { UserDefaults.standard.set(accentColorHex, forKey: "appAccentColor") }
    }
    
    @Published var catppuccinAccentName: String {
        didSet { UserDefaults.standard.set(catppuccinAccentName, forKey: "catppuccinAccent") }
    }
    
    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }
    
    func colors(for colorScheme: ColorScheme) -> ThemeColors {
        ThemeColors.forTheme(theme, colorScheme: colorScheme, accentName: catppuccinAccentName, customAccentHex: accentColorHex)
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
        self.theme = AppTheme(rawValue: savedTheme) ?? .system
        self.accentColorHex = UserDefaults.standard.string(forKey: "appAccentColor") ?? "#0066CC"
        self.catppuccinAccentName = UserDefaults.standard.string(forKey: "catppuccinAccent") ?? "Mauve"
    }
}

// Environment key for theme colors
struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.forTheme(.system, colorScheme: .light, accentName: "Mauve", customAccentHex: "#0066CC")
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
