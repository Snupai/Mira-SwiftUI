import Foundation
import SwiftUI

// MARK: - JSON Theme Models

struct ThemeFile: Codable, Identifiable {
    var id: String { name }
    let name: String
    let author: String?
    let version: String?
    let isSystemTheme: Bool?
    let dark: ThemePalette
    let light: ThemePalette
}

struct ThemePalette: Codable {
    let base: String
    let mantle: String
    let crust: String
    let surface0: String
    let surface1: String
    let surface2: String
    let overlay0: String
    let text: String
    let subtext: String
    let accents: [String: String]
    let defaultAccent: String
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var availableThemes: [ThemeFile] = []
    @Published var selectedThemeName: String {
        didSet {
            UserDefaults.standard.set(selectedThemeName, forKey: "selectedTheme")
        }
    }
    @Published var selectedAccentName: String {
        didSet {
            UserDefaults.standard.set(selectedAccentName, forKey: "selectedAccent")
        }
    }
    @Published var customAccentHex: String {
        didSet {
            UserDefaults.standard.set(customAccentHex, forKey: "customAccentHex")
        }
    }
    
    var selectedTheme: ThemeFile? {
        availableThemes.first { $0.name == selectedThemeName }
    }
    
    private let fileManager = FileManager.default
    
    private var customThemesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let themesDir = appSupport.appendingPathComponent("Mira/Themes", isDirectory: true)
        try? fileManager.createDirectory(at: themesDir, withIntermediateDirectories: true)
        return themesDir
    }
    
    private init() {
        self.selectedThemeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "Default"
        self.selectedAccentName = UserDefaults.standard.string(forKey: "selectedAccent") ?? "Blue"
        self.customAccentHex = UserDefaults.standard.string(forKey: "customAccentHex") ?? "#007aff"
        copyBundledThemesToCustomFolder()
        loadThemes()
    }
    
    /// Copy bundled themes to custom folder so users have examples
    private func copyBundledThemesToCustomFolder() {
        // Ensure folder exists
        try? fileManager.createDirectory(at: customThemesDirectory, withIntermediateDirectories: true)
        
        // Find bundled themes in SPM resource bundle
        guard let resourceBundle = Bundle.main.url(forResource: "Mira_Mira", withExtension: "bundle"),
              let bundle = Bundle(url: resourceBundle),
              let bundlePath = bundle.resourcePath else { return }
        
        let bundleURL = URL(fileURLWithPath: bundlePath)
        guard let files = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) else { return }
        
        for file in files where file.pathExtension == "json" {
            let destURL = customThemesDirectory.appendingPathComponent(file.lastPathComponent)
            // Only copy if doesn't exist (don't overwrite user edits)
            if !fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.copyItem(at: file, to: destURL)
            }
        }
    }
    
    /// Opens the custom themes folder in Finder
    func openThemesFolder() {
        // Ensure folder exists
        try? fileManager.createDirectory(at: customThemesDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(customThemesDirectory)
    }
    
    func loadThemes() {
        var themes: [ThemeFile] = []
        
        // Load bundled themes - try multiple locations
        // 1. Check for JSON files in the main bundle's resource path
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            themes.append(contentsOf: loadThemesFrom(directory: resourceURL))
            
            // Also check Themes subdirectory
            let themesPath = resourceURL.appendingPathComponent("Themes")
            themes.append(contentsOf: loadThemesFrom(directory: themesPath))
        }
        
        // 2. Check for JSON files in any bundle resources
        if let bundleThemes = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            for url in bundleThemes {
                if let theme = loadTheme(from: url), !themes.contains(where: { $0.name == theme.name }) {
                    themes.append(theme)
                }
            }
        }
        
        // 3. Check Mira_Mira.bundle specifically (SPM resource bundle)
        if let resourceBundle = Bundle.main.url(forResource: "Mira_Mira", withExtension: "bundle"),
           let bundle = Bundle(url: resourceBundle) {
            if let bundlePath = bundle.resourcePath {
                themes.append(contentsOf: loadThemesFrom(directory: URL(fileURLWithPath: bundlePath)))
            }
        }
        
        // Load custom themes from Application Support
        themes.append(contentsOf: loadThemesFrom(directory: customThemesDirectory))
        
        // Remove duplicates (keep first occurrence)
        var seen = Set<String>()
        themes = themes.filter { theme in
            if seen.contains(theme.name) { return false }
            seen.insert(theme.name)
            return true
        }
        
        // If no themes loaded, create default Catppuccin in memory
        if themes.isEmpty {
            themes.append(createDefaultCatppuccin())
        }
        
        availableThemes = themes.sorted { $0.name < $1.name }
        
        // Ensure selected theme exists
        if !availableThemes.contains(where: { $0.name == selectedThemeName }) {
            selectedThemeName = availableThemes.first?.name ?? "Catppuccin"
        }
    }
    
    private func loadThemesFrom(directory: URL) -> [ThemeFile] {
        var themes: [ThemeFile] = []
        
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return themes
        }
        
        for file in files where file.pathExtension == "json" {
            if let theme = loadTheme(from: file) {
                themes.append(theme)
            }
        }
        
        return themes
    }
    
    private func loadTheme(from url: URL) -> ThemeFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ThemeFile.self, from: data)
    }
    
    private func createDefaultCatppuccin() -> ThemeFile {
        ThemeFile(
            name: "Catppuccin",
            author: "Catppuccin",
            version: "1.0",
            isSystemTheme: false,
            dark: ThemePalette(
                base: "#1e1e2e", mantle: "#181825", crust: "#11111b",
                surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
                overlay0: "#6c7086", text: "#cdd6f4", subtext: "#a6adc8",
                accents: ["Mauve": "#cba6f7", "Pink": "#f5c2e7", "Blue": "#89b4fa"],
                defaultAccent: "Mauve"
            ),
            light: ThemePalette(
                base: "#eff1f5", mantle: "#e6e9ef", crust: "#dce0e8",
                surface0: "#ccd0da", surface1: "#bcc0cc", surface2: "#acb0be",
                overlay0: "#9ca0b0", text: "#4c4f69", subtext: "#6c6f85",
                accents: ["Mauve": "#8839ef", "Pink": "#ea76cb", "Blue": "#1e66f5"],
                defaultAccent: "Mauve"
            )
        )
    }
    
    // MARK: - Color Resolution
    
    func colors(for colorScheme: ColorScheme) -> ThemeColors {
        guard let theme = selectedTheme else {
            return ThemeColors.fallback
        }
        
        let palette = colorScheme == .dark ? theme.dark : theme.light
        let isSystem = theme.isSystemTheme ?? false
        
        let accent: Color
        if let accentHex = palette.accents[selectedAccentName] {
            accent = resolveColor(accentHex, isSystem: isSystem)
        } else if let defaultHex = palette.accents[palette.defaultAccent] {
            accent = resolveColor(defaultHex, isSystem: isSystem)
        } else {
            accent = Color(hex: customAccentHex) ?? .purple
        }
        
        return ThemeColors(
            base: resolveColor(palette.base, isSystem: isSystem),
            mantle: resolveColor(palette.mantle, isSystem: isSystem),
            crust: resolveColor(palette.crust, isSystem: isSystem),
            surface0: resolveColor(palette.surface0, isSystem: isSystem),
            surface1: resolveColor(palette.surface1, isSystem: isSystem),
            surface2: resolveColor(palette.surface2, isSystem: isSystem),
            overlay0: resolveColor(palette.overlay0, isSystem: isSystem),
            text: resolveColor(palette.text, isSystem: isSystem),
            subtext: resolveColor(palette.subtext, isSystem: isSystem),
            accent: accent
        )
    }
    
    private func resolveColor(_ value: String, isSystem: Bool) -> Color {
        // Handle system colors
        if value.hasPrefix("system:") {
            let systemName = String(value.dropFirst(7))
            return systemColor(named: systemName)
        }
        
        // Handle rgba
        if value.hasPrefix("rgba:") {
            let components = value.dropFirst(5).split(separator: ",")
            if components.count == 4,
               let r = Double(components[0]),
               let g = Double(components[1]),
               let b = Double(components[2]),
               let a = Double(components[3]) {
                return Color(red: r/255, green: g/255, blue: b/255, opacity: a)
            }
        }
        
        // Handle hex
        return Color(hex: value) ?? .gray
    }
    
    private func systemColor(named name: String) -> Color {
        switch name {
        case "windowBackground": return Color(nsColor: .windowBackgroundColor)
        case "controlBackground": return Color(nsColor: .controlBackgroundColor)
        case "separator": return Color(nsColor: .separatorColor)
        case "label": return Color(nsColor: .labelColor)
        case "secondaryLabel": return Color(nsColor: .secondaryLabelColor)
        case "accent": return Color.accentColor
        default: return .gray
        }
    }
    
    // MARK: - Theme Import
    
    func importTheme(from url: URL) -> Bool {
        guard let theme = loadTheme(from: url) else { return false }
        
        let destination = customThemesDirectory.appendingPathComponent("\(theme.name).json")
        
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            loadThemes()
            return true
        } catch {
            print("Failed to import theme: \(error)")
            return false
        }
    }
    
    func deleteCustomTheme(_ theme: ThemeFile) {
        let path = customThemesDirectory.appendingPathComponent("\(theme.name).json")
        try? fileManager.removeItem(at: path)
        loadThemes()
    }
    
    func accentNames(for colorScheme: ColorScheme) -> [String] {
        guard let theme = selectedTheme else { return [] }
        let palette = colorScheme == .dark ? theme.dark : theme.light
        return Array(palette.accents.keys).sorted()
    }
}
