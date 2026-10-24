import SwiftUI

// MARK: - Layout tokens
//
// Mira's content layer is deliberately quiet: flat surfaces, system semantic
// colors, and whitespace instead of card chrome. Liquid Glass is reserved for
// the navigation layer (sidebar, toolbar, inspector) which the system paints
// for us, plus the one floating element we own: the invoice paper.

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Horizontal inset for scrolling content areas (dashboard, detail panes).
    static let page: CGFloat = 28
}

enum Radius {
    static let control: CGFloat = 8
    static let group: CGFloat = 12
    static let paper: CGFloat = 4
}

/// Maximum width for long-form reading content so line lengths stay comfortable.
enum ContentWidth {
    static let reading: CGFloat = 760
    static let inspector: CGFloat = 320
}

// MARK: - Money

/// One formatter for every amount in the app, so money reads the same on the
/// dashboard, in tables, in the inspector and on the paper preview.
enum Money {
    private static var cache: [String: NumberFormatter] = [:]

    static func formatter(for currency: Currency) -> NumberFormatter {
        if let cached = cache[currency.rawValue] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        cache[currency.rawValue] = f
        return f
    }

    static func string(_ value: Double, _ currency: Currency) -> String {
        formatter(for: currency).string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }

    /// Whole-unit formatting for large dashboard numbers ("€4,820").
    static func compact(_ value: Double, _ currency: Currency) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0"
    }

    static func quantity(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.2f", q)
    }
}

/// Right-aligned, tabular-digit amount. Use for every money column.
struct MoneyText: View {
    let value: Double
    let currency: Currency
    var font: Font = .body
    var weight: Font.Weight = .regular

    init(_ value: Double, _ currency: Currency, font: Font = .body, weight: Font.Weight = .regular) {
        self.value = value
        self.currency = currency
        self.font = font
        self.weight = weight
    }

    var body: some View {
        Text(Money.string(value, currency))
            .font(font.weight(weight))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Dates

enum Dates {
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    static func relativeDue(_ due: Date, status: InvoiceStatus) -> String? {
        guard status == .sent || status == .overdue else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<(-1): return "\(-days) days overdue"
        case -1: return "1 day overdue"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }
}

// MARK: - Status

extension InvoiceStatus {
    /// Semantic tint. Sent uses the app accent so it reads as "in flight";
    /// everything else uses system colors so it adapts to light/dark.
    func tint(accent: Color) -> Color {
        switch self {
        case .draft: return .secondary
        case .sent: return accent
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }

    var symbol: String { icon }
}

/// Small capsule showing an invoice's status.
struct StatusBadge: View {
    let status: InvoiceStatus
    var prominent: Bool = false
    @Environment(\.themeColors) private var colors

    var body: some View {
        let tint = status.tint(accent: colors.accent)
        Label(status.rawValue, systemImage: status.symbol)
            .labelStyle(.titleOnly)
            .font(prominent ? .callout.weight(.semibold) : .caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, prominent ? 10 : 8)
            .padding(.vertical, prominent ? 5 : 3)
            .background(tint.opacity(0.14), in: Capsule())
            .accessibilityLabel("Status: \(status.rawValue)")
    }
}

// MARK: - Section headers

/// Plain section title used in scrolling content. Sentence case, no eyebrow.
struct SectionTitle: View {
    let title: String
    var trailing: AnyView? = nil

    init(_ title: String) {
        self.title = title
    }

    init<T: View>(_ title: String, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            trailing
        }
    }
}

/// Label/value pair for metadata rows (inspector, client detail).
struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.m)
            Text(value)
                .foregroundStyle(valueColor ?? .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

// MARK: - Scroll backgrounds

/// Grouped forms, inset lists and tables paint an opaque system background of
/// their own, which covers the palette base a custom theme paints behind the
/// window. This hides that layer for custom palettes and leaves it alone for
/// the system palette, so every scrolling container shows the same base.
struct ThemedScrollBackground: ViewModifier {
    @Environment(\.themeColors) private var colors

    func body(content: Content) -> some View {
        content.scrollContentBackground(colors.isSystem ? .automatic : .hidden)
    }
}

extension View {
    /// Apply to every `Form`, `List` and `Table` in a themed window.
    func themedScrollBackground() -> some View {
        modifier(ThemedScrollBackground())
    }

    /// The app's standard grouped form, with the palette base showing through.
    func themedGroupedForm() -> some View {
        formStyle(.grouped).themedScrollBackground()
    }
}

// MARK: - Glass helpers

extension View {
    /// Liquid Glass for elements we float above content (paper actions, chips).
    /// Keep usage rare: the system already paints glass for sidebar/toolbar.
    func floatingGlass<S: Shape>(in shape: S = Capsule()) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// Flat grouped surface for content-layer containers. Uses the system's
    /// quaternary fill so it adapts to light/dark and to custom theme bases.
    func groupedSurface(cornerRadius: CGFloat = Radius.group) -> some View {
        background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Client avatar

struct ClientAvatar: View {
    let name: String
    var size: CGFloat = 36
    @Environment(\.themeColors) private var colors

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(colors.accent)
            .frame(width: size, height: size)
            .background(colors.accent.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}
