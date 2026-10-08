import SwiftUI

private struct MiraInputStyle: ViewModifier {
    let colors: ThemeColors
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colors.surface1, in: RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func miraInput(colors: ThemeColors) -> some View {
        modifier(MiraInputStyle(colors: colors))
    }
}
