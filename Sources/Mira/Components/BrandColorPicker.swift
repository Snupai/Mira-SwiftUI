import SwiftUI

struct BrandColorPicker: View {
    @Binding var selectedColorHex: String
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brand Color")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(BrandColors.presets, id: \.hex) { preset in
                    ColorSwatch(
                        color: Color(hex: preset.hex) ?? .blue,
                        name: preset.name,
                        isSelected: selectedColorHex.uppercased() == preset.hex.uppercased(),
                        action: { selectedColorHex = preset.hex }
                    )
                }
            }
            
            // Custom color input
            HStack {
                Text("Custom:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("#0066CC", text: $selectedColorHex)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .font(.system(.body, design: .monospaced))
                
                if let color = Color(hex: selectedColorHex) {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.top, 8)
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
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                    
                    if isSelected {
                        Circle()
                            .stroke(color, lineWidth: 3)
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? color : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logo Picker

struct LogoPicker: View {
    @Binding var logoData: Data?
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brand Logo")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                // Logo preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 80)
                    
                    if let logoData = logoData, let image = imageFromData(logoData) {
                        #if os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 60)
                        #else
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 60)
                        #endif
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No logo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showingImagePicker = true }) {
                        Label("Choose Image", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    
                    if logoData != nil {
                        Button(action: { logoData = nil }) {
                            Label("Remove", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("PNG or JPG, max 1MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadImage(from: url)
                }
            case .failure(let error):
                print("Error selecting image: \(error)")
            }
        }
    }
    
    private func loadImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            // Limit to 1MB
            if data.count <= 1_000_000 {
                logoData = data
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
    
    #if os(macOS)
    private func imageFromData(_ data: Data) -> NSImage? {
        NSImage(data: data)
    }
    #else
    private func imageFromData(_ data: Data) -> UIImage? {
        UIImage(data: data)
    }
    #endif
}

// Preview
struct BrandColorPicker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            BrandColorPicker(selectedColorHex: .constant("#0066CC"))
            LogoPicker(logoData: .constant(nil))
        }
        .padding()
    }
}
