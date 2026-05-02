import Foundation

/// Centralized opacity values used across SwiftUI views, so reviewers don't have
/// to guess the intent behind a literal `0.15` or `0.5`.
enum Opacity {
    /// Subtle backgrounds, hairline dividers, very-low-emphasis fills.
    static let subtle: Double = 0.15
    /// Mid-emphasis surfaces — disabled-but-visible controls, secondary text overlays.
    static let muted: Double = 0.5
}

/// Sizing factors used to shrink controls in compact contexts.
enum Sizing {
    /// Reduce a control to ~70% — used for inline icons and small toggles.
    static let smallControlScale: CGFloat = 0.7
}

/// Sample data values reused across previews and onboarding placeholders.
/// Centralizing them keeps preview/placeholder text consistent and de-duplicates
/// hard-coded literals across the codebase.
enum SampleData {
    /// Example BIC used in onboarding placeholders and SwiftUI previews.
    /// Commerzbank's primary BIC; well-known, format-correct, and not a real account.
    static let placeholderBIC = "COBADEFFXXX"

    /// Example IBAN matching the placeholder BIC. Same provenance: well-known
    /// example, not a real account.
    static let placeholderIBAN = "DE89370400440532013000"
}
