import SwiftUI
import UniformTypeIdentifiers

struct ThemePicker: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var themeToExport: ThemeFile?
    @State private var importError: String?
    @State private var showingImportError = false
    
    var compact: Bool = false
    var showOpenFolder: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            HStack {
                if !compact {
                    Text("Choose Theme")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Import button
                    Button(action: { showingImportPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            if !compact {
                                Text("Import")
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Import Theme – Load a custom theme from a JSON file")
                    
                    // Export current theme button
                    if let theme = themeManager.selectedTheme {
                        Button(action: {
                            themeToExport = theme
                            showingExportPicker = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                if !compact {
                                    Text("Export")
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Export Theme – Save \"\(theme.name)\" as a JSON file to share or backup")
                    }
                    
                    if showOpenFolder {
                        Button(action: { themeManager.openThemesFolder() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                if !compact {
                                    Text("Folder")
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Open Themes Folder – Browse custom themes in Finder")
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: compact ? 100 : 140), spacing: 12)
            ], spacing: 12) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: theme.name == themeManager.selectedThemeName,
                        compact: compact,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.selectedThemeName = theme.name
                                // Reset accent to theme default
                                let palette = colorScheme == .dark ? theme.dark : theme.light
                                themeManager.selectedAccentName = palette.defaultAccent
                            }
                        },
                        onDelete: {
                            themeManager.deleteCustomTheme(theme)
                        }
                    )
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
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Need to access security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Unable to access the selected file"
                        showingImportError = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    if themeManager.importTheme(from: url) {
                        // Success - theme is now loaded
                    } else {
                        importError = "Failed to import theme. Make sure it's a valid Mira theme JSON file."
                        showingImportError = true
                    }
                }
            case .failure(let error):
                importError = error.localizedDescription
                showingImportError = true
            }
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: themeToExport.map { ThemeDocument(theme: $0) },
            contentType: .json,
            defaultFilename: themeToExport?.name ?? "theme"
        ) { result in
            if case .failure(let error) = result {
                importError = "Export failed: \(error.localizedDescription)"
                showingImportError = true
            }
        }
        .alert("Theme Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }
}

// Document wrapper for theme export
struct ThemeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let theme: ThemeFile
    
    init(theme: ThemeFile) {
        self.theme = theme
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.theme = try JSONDecoder().decode(ThemeFile.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ThemeCard: View {
    let theme: ThemeFile
    let isSelected: Bool
    let compact: Bool
    let action: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirm = false
    
    var palette: ThemePalette {
        colorScheme == .dark ? theme.dark : theme.light
    }
    
    /// Bundled themes that cannot be deleted
    private static let protectedThemes = ["Default", "Catppuccin"]
    
    var canDelete: Bool {
        // Don't allow deletion of system themes or protected bundled themes
        if theme.isSystemTheme == true { return false }
        if Self.protectedThemes.contains(theme.name) { return false }
        return true
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
                HStack(spacing: 4) {
                    Text(theme.name)
                        .font(compact ? .caption : .subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let author = theme.author {
                Text("By \(author)")
            }
            if let version = theme.version {
                Text("Version \(version)")
            }
            Divider()
            Text("\(palette.accents.count) accent colors")
            if canDelete && onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete Theme", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(theme.name)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the theme file.")
        }
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
