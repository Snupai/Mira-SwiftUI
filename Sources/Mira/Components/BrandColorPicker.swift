import SwiftUI
import UniformTypeIdentifiers

/// Grid of brand color presets plus a hex field. Used where a full-width
/// picker fits (onboarding); Settings uses a compact inline row.
struct BrandColorPicker: View {
    @Binding var selectedColorHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(BrandColors.presets, id: \.hex) { preset in
                    ColorSwatch(
                        color: Color(hex: preset.hex) ?? .blue,
                        name: preset.name,
                        isSelected: selectedColorHex.uppercased() == preset.hex.uppercased(),
                        action: { selectedColorHex = preset.hex }
                    )
                }
            }

            HStack(spacing: Spacing.s) {
                Text("Custom")
                    .foregroundStyle(.secondary)
                TextField("#0066CC", text: $selectedColorHex)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .font(.body.monospaced())
                if let color = Color(hex: selectedColorHex) {
                    Circle()
                        .fill(color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(.quaternary, lineWidth: 1))
                }
            }
            .font(.callout)
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Logo Picker

/// Form-friendly logo row: thumbnail, choose/remove buttons, size hint.
struct LogoPicker: View {
    @Binding var logoData: Data?
    @State private var showingImagePicker = false
    @State private var importError: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.l) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 96, height: 64)

                if let logoData, let image = NSImage(data: logoData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 52)
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(logoData == nil ? "No logo" : "Current logo")

            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Button("Choose image…") { showingImagePicker = true }
                        .buttonStyle(.bordered)
                    if logoData != nil {
                        Button("Remove") { logoData = nil }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }
                Text("PNG or JPG up to 1 MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.png, .jpeg, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { loadImage(from: url) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Couldn't use that image", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func loadImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Mira wasn't allowed to read the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            if data.count <= 1_000_000 {
                logoData = data
            } else {
                importError = "The image is larger than 1 MB. Choose a smaller file."
            }
        } catch {
            importError = "The file couldn't be read: \(error.localizedDescription)"
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        BrandColorPicker(selectedColorHex: .constant("#0066CC"))
        LogoPicker(logoData: .constant(nil))
    }
    .padding()
}
