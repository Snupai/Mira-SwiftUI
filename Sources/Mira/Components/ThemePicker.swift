import SwiftUI

struct ThemePicker: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var compact: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            if !compact {
                Text("Choose Theme")
                    .font(.headline)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: compact ? 100 : 140), spacing: 12)
            ], spacing: 12) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: theme.name == themeManager.selectedThemeName,
                        compact: compact
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.selectedThemeName = theme.name
                            // Reset accent to theme default
                            let palette = colorScheme == .dark ? theme.dark : theme.light
                            themeManager.selectedAccentName = palette.defaultAccent
                        }
                    }
                }
            }
            
            // Accent color picker (if theme has multiple accents)
            if let theme = themeManager.selectedTheme {
                let palette = colorScheme == .dark ? theme.dark : theme.light
                if palette.accents.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        if !compact {
                            Text("Accent Color")
                                .font(.headline)
                                .padding(.top, 8)
                        }
                        
                        AccentPicker(
                            accents: palette.accents,
                            selected: $themeManager.selectedAccentName,
                            compact: compact
                        )
                    }
                }
            }
        }
    }
}

struct ThemeCard: View {
    let theme: ThemeFile
    let isSelected: Bool
    let compact: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var palette: ThemePalette {
        colorScheme == .dark ? theme.dark : theme.light
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 6 : 10) {
                // Theme preview
                ThemePreview(palette: palette, compact: compact)
                    .frame(height: compact ? 50 : 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                
                // Theme name
                Text(theme.name)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ThemePreview: View {
    let palette: ThemePalette
    let compact: Bool
    
    private func resolveColor(_ hex: String) -> Color {
        if hex.hasPrefix("system:") || hex.hasPrefix("rgba:") {
            return Color.gray // Simplified for preview
        }
        return Color(hex: hex) ?? .gray
    }
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Base color
                resolveColor(palette.base)
                    .frame(width: geo.size.width * 0.4)
                
                VStack(spacing: 0) {
                    // Surface colors
                    resolveColor(palette.surface0)
                    resolveColor(palette.surface1)
                }
                .frame(width: geo.size.width * 0.3)
                
                VStack(spacing: 0) {
                    // Text preview
                    resolveColor(palette.text)
                    // Accent preview
                    if let accentHex = palette.accents[palette.defaultAccent] {
                        resolveColor(accentHex)
                    } else {
                        Color.purple
                    }
                }
                .frame(width: geo.size.width * 0.3)
            }
        }
    }
}

struct AccentPicker: View {
    let accents: [String: String]
    @Binding var selected: String
    let compact: Bool
    
    var sortedAccents: [(name: String, hex: String)] {
        accents.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: compact ? 6 : 10) {
                ForEach(sortedAccents, id: \.name) { accent in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = accent.name
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: accent.hex) ?? .gray)
                                .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)
                                .overlay(
                                    Circle()
                                        .stroke(selected == accent.name ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            
                            if !compact {
                                Text(accent.name)
                                    .font(.caption2)
                                    .foregroundColor(selected == accent.name ? .primary : .secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
