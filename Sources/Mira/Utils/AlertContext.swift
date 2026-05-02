import SwiftUI

/// Lightweight bag of alert state any view can route failures through.
///
/// Use with the `.alert(item:)` SwiftUI modifier:
/// ```swift
/// @State private var alertContext: AlertContext?
///
/// view
///     .alert(item: $alertContext) { context in
///         context.alert
///     }
/// ```
///
/// Then surface failures by setting the state:
/// ```swift
/// alertContext = AlertContext(
///     title: "Export Failed",
///     message: error.localizedDescription
/// )
/// ```
struct AlertContext: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    /// Optional primary action label (e.g. "Retry"). When nil, only the dismiss button is shown.
    let primaryButtonTitle: String?
    /// Optional primary action handler.
    let primaryAction: (() -> Void)?
    /// Label of the cancel/dismiss button. Defaults to "OK".
    let dismissButtonTitle: String

    init(
        title: String,
        message: String,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        dismissButtonTitle: String = "OK"
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.dismissButtonTitle = dismissButtonTitle
    }

    /// Convenience initializer from a thrown `Error`.
    init(title: String, error: Error) {
        self.init(title: title, message: error.localizedDescription)
    }

    /// Build a SwiftUI `Alert` for this context.
    var alert: Alert {
        if let primary = primaryButtonTitle, let action = primaryAction {
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .default(Text(primary), action: action),
                secondaryButton: .cancel(Text(dismissButtonTitle))
            )
        }
        return Alert(
            title: Text(title),
            message: Text(message),
            dismissButton: .default(Text(dismissButtonTitle))
        )
    }
}
