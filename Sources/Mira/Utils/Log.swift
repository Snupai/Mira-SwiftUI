import Foundation
import os

/// Centralized logging facade for Mira.
///
/// Use these `Logger` instances instead of `print()` so that:
///  - Messages respect privacy (`@available(macOS 11+)` `os.Logger` redacts dynamic
///    interpolations by default unless explicitly marked `.public`).
///  - Categories can be filtered in Console.app (filter by subsystem
///    `com.snupai.Mira`).
///  - Levels are honored: `.debug` is stripped from Release builds, `.info`
///    is captured in memory only, `.notice`/`.error`/`.fault` are persisted.
///
/// Example:
/// ```swift
/// Log.migration.notice("Migrating \(count) invoices")
/// Log.data.error("Failed to load profile: \(error.localizedDescription, privacy: .public)")
/// ```
enum Log {
    /// Subsystem identifier used for all loggers; matches the app bundle id.
    static let subsystem = "com.snupai.Mira"

    /// App lifecycle, navigation, command handling.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Legacy JSON → SwiftData migration.
    static let migration = Logger(subsystem: subsystem, category: "migration")

    /// SwiftData container creation, persistence, queries.
    static let data = Logger(subsystem: subsystem, category: "data")

    /// CloudKit account status, sync, container lookups.
    static let cloudKit = Logger(subsystem: subsystem, category: "cloudKit")

    /// Theme loading, parsing, import/export.
    static let theme = Logger(subsystem: subsystem, category: "theme")

    /// Field-level encryption, key handling, integrity checks.
    static let encryption = Logger(subsystem: subsystem, category: "encryption")

    /// Onboarding flow steps and persistence.
    static let onboarding = Logger(subsystem: subsystem, category: "onboarding")

    /// PDF generation, layout, locale rendering.
    static let pdf = Logger(subsystem: subsystem, category: "pdf")
}
