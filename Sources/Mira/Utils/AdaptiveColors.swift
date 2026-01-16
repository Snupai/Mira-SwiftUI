import SwiftUI

// Adaptive colors that work in both light and dark mode
extension Color {
    // Backgrounds
    static var appBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    
    static var secondaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    static var tertiaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }
    
    // For input fields - subtle background
    static var inputBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor).opacity(0.5)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    // For cards/sections
    static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor).opacity(0.3)
        #else
        Color(uiColor: .secondarySystemBackground).opacity(0.5)
        #endif
    }
    
    // Button colors
    static var buttonBackground: Color {
        Color.accentColor
    }
    
    static var buttonForeground: Color {
        Color.white
    }
    
    static var secondaryButtonBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlColor)
        #else
        Color(uiColor: .systemGray5)
        #endif
    }
}
