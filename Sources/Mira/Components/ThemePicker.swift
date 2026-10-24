import SwiftUI
import UniformTypeIdentifiers

/// Theme grid with accent swatches and import/export controls.
struct ThemePicker: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeColors) private var colors
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var themeToExport: ThemeFile?
    @State private var importError: String?

    var compact: Bool = false
    var showOpenFolder: Bool = true

    private var currentPalette: ThemePalette? {
        guard let theme = themeManager.selectedTheme else { return nil }
        return colorScheme == .dark ? theme.dark : theme.light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Spacing.m : Spacing.l) {
            HStack {
                Text("Theme")
                    .font(compact ? .callout : .headline)
                Spacer()
                HStack(spacing: Spacing.s) {
                    Button("Import…") { showingImportPicker = true }
                        .help("Load a theme from a JSON file")
                    if let theme = themeManager.selectedTheme {
                        Button("Export…") {
                            themeToExport = theme
                            showingExportPicker = true
                        }
                        .help("Save \"\(theme.name)\" as a JSON file")
                    }
                    if showOpenFolder {
                        Button("Show folder") { themeManager.openThemesFolder() }
                            .help("Open the themes folder in Finder")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 100 : 120, maximum: compact ? 140 : 160), spacing: Spacing.m, alignment: .leading)], alignment: .leading, spacing: Spacing.m) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: theme.name == themeManager.selectedThemeName,
                        compact: compact,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.selectedThemeName = theme.name
                                let palette = colorScheme == .dark ? theme.dark : theme.light
                                themeManager.selectedAccentName = palette.defaultAccent
                            }
                        },
                        onDelete: { themeManager.deleteCustomTheme(theme) }
                    )
                }
            }

            if let palette = currentPalette, palette.accents.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Accent")
                        .font(compact ? .callout : .headline)
                    AccentPicker(accents: palette.accents, selected: $themeManager.selectedAccentName, compact: compact)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    importError = "Mira wasn't allowed to read the selected file."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                if !themeManager.importTheme(from: url) {
                    importError = "That file isn't a valid Mira theme. Export an existing theme to see the expected format."
                }
            case .failure(let error):
                importError = error.localizedDescription
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
            }
        }
        .alert("Couldn't import theme", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }
}

// Document wrapper for theme export
@preconcurrency
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
    @Environment(\.themeColors) private var colors
    @State private var showingDeleteConfirm = false

    var palette: ThemePalette {
        colorScheme == .dark ? theme.dark : theme.light
    }

    /// Bundled themes that cannot be deleted.
    private static let protectedThemes = ["Default", "Catppuccin"]

    var canDelete: Bool {
        if theme.isSystemTheme == true { return false }
        if Self.protectedThemes.contains(theme.name) { return false }
        return true
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                ThemePreview(palette: palette)
                    .frame(width: compact ? 100 : 120, height: compact ? 54 : 64)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(isSelected ? colors.accent : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
                Text(theme.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    Label("Delete theme", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete \"\(theme.name)\"?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete theme", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the theme file.")
        }
    }
}

/// Miniature window: sidebar strip, content area, a text line and an accent chip.
struct ThemePreview: View {
    let palette: ThemePalette

    private func resolve(_ value: String) -> Color {
        if value.hasPrefix("system:") {
            switch String(value.dropFirst(7)) {
            case "windowBackground": return Color(nsColor: .windowBackgroundColor)
            case "underPageBackground": return Color(nsColor: .underPageBackgroundColor)
            case "label": return Color(nsColor: .labelColor)
            case "secondaryLabel": return Color(nsColor: .secondaryLabelColor)
            case "quaternaryFill": return Color(nsColor: .labelColor).opacity(0.05)
            case "tertiaryFill": return Color(nsColor: .labelColor).opacity(0.10)
            default: return Color(nsColor: .controlBackgroundColor)
            }
        }
        return Color(hex: value) ?? .gray
    }

    private var accent: Color {
        palette.accents[palette.defaultAccent].map(resolve) ?? .purple
    }

    var body: some View {
        HStack(spacing: 0) {
            resolve(palette.mantle)
                .frame(width: 28)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(accent).frame(width: 14, height: 3)
                        Capsule().fill(resolve(palette.surface1)).frame(width: 16, height: 3)
                        Capsule().fill(resolve(palette.surface1)).frame(width: 12, height: 3)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            resolve(palette.base)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(resolve(palette.text)).frame(width: 34, height: 4)
                        Capsule().fill(resolve(palette.subtext)).frame(width: 50, height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(resolve(palette.surface0)).frame(height: 14).padding(.top, 2)
                    }
                    .padding(8)
                }
        }
    }
}

struct AccentPicker: View {
    let accents: [String: String]
    @Binding var selected: String
    let compact: Bool

    private var sortedAccents: [(name: String, hex: String)] {
        accents.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        // Wraps instead of scrolling so it never overflows narrow panes.
        SimpleFlowLayout(spacing: compact ? Spacing.s : Spacing.m) {
            ForEach(sortedAccents, id: \.name) { accent in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = accent.name }
                } label: {
                    Circle()
                        .fill(Color(hex: accent.hex) ?? .gray)
                        .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                        .overlay {
                            if selected == accent.name {
                                Image(systemName: "checkmark")
                                    .font(.system(size: compact ? 10 : 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(accent.name)
                .accessibilityLabel(accent.name)
                .accessibilityAddTraits(selected == accent.name ? .isSelected : [])
            }
        }
    }
}
