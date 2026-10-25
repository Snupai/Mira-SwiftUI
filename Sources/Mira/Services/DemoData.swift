import Foundation
import SwiftData
import os

/// Launch Mira with `MIRA_DEMO=1` to run against an in-memory store seeded
/// with a realistic freelancer's data. Nothing is written to disk, so it is
/// safe for screenshots, design review and manual QA.
///
///     MIRA_DEMO=1 ./Mira.app/Contents/MacOS/Mira
///
/// `MIRA_UI_REVIEW=1` (used by `script/build_and_run.sh --ui-review`) is an
/// alias for the same isolated mode.
///
/// Add `MIRA_DEMO_EMPTY=1` to seed only the company profile.
enum DemoData {
    static var isEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["MIRA_DEMO"] == "1" || env["MIRA_UI_REVIEW"] == "1"
    }

    /// In-memory container with demo content. Also marks onboarding and
    /// migration as complete for this process only (registered defaults are
    /// never persisted).
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        UserDefaults.standard.register(defaults: [
            "hasCompletedOnboarding": ProcessInfo.processInfo.environment["MIRA_ONBOARDING"] != "1",
            "mira.migrationStatus": "completed",
        ])
        let container = try DataContainer.createPreviewContainer()
        seed(container.mainContext)
        Log.data.notice("Demo mode: using in-memory store with sample data")
        return container
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today) ?? today }
        func days(_ n: Int, after date: Date) -> Date { calendar.date(byAdding: .day, value: n, to: date) ?? date }

        // Profile
        var profile = CompanyProfile()
        profile.companyName = "Studio Nord"
        profile.ownerName = "Jana Weber"
        profile.email = "hallo@studionord.de"
        profile.phone = "+49 40 1234567"
        profile.website = "studionord.de"
        profile.street = "Hafenstraße 12"
        profile.postalCode = "20457"
        profile.city = "Hamburg"
        profile.country = "Germany"
        profile.vatId = "DE123456789"
        profile.taxNumber = "41/234/56789"
        profile.bankName = "Commerzbank"
        profile.iban = SampleData.placeholderIBAN
        profile.bic = SampleData.placeholderBIC
        profile.accountHolder = "Jana Weber"
        profile.brandColorHex = "#1a237e"
        profile.invoiceNumberPrefix = "SN-"
        profile.nextInvoiceNumber = 15
        context.insert(SDCompanyProfile(from: profile))

        // `MIRA_DEMO_EMPTY=1` stops here: a freshly onboarded user with no
        // clients or invoices, for first-run screens.
        if ProcessInfo.processInfo.environment["MIRA_DEMO_EMPTY"] == "1" {
            try? context.save()
            return
        }

        // Clients
        func makeClient(_ name: String, contact: String, email: String, street: String, postal: String, city: String, country: String = "Germany", currency: Currency? = nil, language: String = "de", vat: String = "") -> SDClient {
            var c = Client()
            c.name = name
            c.contactPerson = contact
            c.email = email
            c.street = street
            c.postalCode = postal
            c.city = city
            c.country = country
            c.defaultCurrency = currency
            c.language = language
            c.vatId = vat
            let sd = SDClient(from: c)
            context.insert(sd)
            return sd
        }
        let acme = makeClient("Acme GmbH", contact: "Lena Hartmann", email: "lena.hartmann@acme.de", street: "Musterstraße 1", postal: "10115", city: "Berlin", vat: "DE987654321")
        let lichtwerk = makeClient("Lichtwerk Studio", contact: "Tom Brandt", email: "tom@lichtwerk.studio", street: "Schanzenstraße 44", postal: "20357", city: "Hamburg")
        let nordwind = makeClient("Nordwind Media", contact: "Sara Klein", email: "sara@nordwind-media.de", street: "Rheinuferweg 8", postal: "50668", city: "Köln")
        let bright = makeClient("Bright & Co Ltd", contact: "Oliver Reed", email: "oliver@brightandco.co.uk", street: "14 Clerkenwell Road", postal: "EC1M 5PS", city: "London", country: "United Kingdom", currency: .gbp, language: "en", vat: "GB123456789")

        // Invoices
        struct Spec {
            var number: Int
            var client: SDClient
            var issued: Date
            var terms: Int
            var status: InvoiceStatus
            var items: [(String, Double, Double)]
            var currency: Currency = .eur
            var rate: Double? = nil
            var paidDaysAfter: Int = 12
            var notes: String = ""
        }
        let specs: [Spec] = [
            Spec(number: 1, client: acme, issued: daysAgo(168), terms: 14, status: .paid, items: [("Brand identity workshop", 1, 1800), ("Logo refinement, 3 rounds", 6, 95)]),
            Spec(number: 2, client: lichtwerk, issued: daysAgo(150), terms: 14, status: .paid, items: [("Website redesign, phase 1", 1, 3200)]),
            Spec(number: 3, client: nordwind, issued: daysAgo(136), terms: 30, status: .paid, items: [("Editorial layout, 24 pages", 24, 110)]),
            Spec(number: 4, client: bright, issued: daysAgo(121), terms: 30, status: .paid, items: [("Pitch deck design", 1, 1450)], currency: .gbp, rate: 1.17),
            Spec(number: 5, client: acme, issued: daysAgo(104), terms: 14, status: .paid, items: [("Social media templates", 12, 85)]),
            Spec(number: 6, client: lichtwerk, issued: daysAgo(92), terms: 14, status: .paid, items: [("Website redesign, phase 2", 1, 2800), ("Hosting setup", 2, 180)]),
            Spec(number: 7, client: nordwind, issued: daysAgo(71), terms: 30, status: .paid, items: [("Illustration set, 8 motifs", 8, 220)]),
            Spec(number: 8, client: acme, issued: daysAgo(58), terms: 14, status: .paid, items: [("Quarterly design retainer", 1, 2400)]),
            Spec(number: 9, client: bright, issued: daysAgo(44), terms: 30, status: .cancelled, items: [("Event signage", 1, 900)], currency: .gbp, notes: "Event postponed; re-issue when the new date is set."),
            Spec(number: 10, client: lichtwerk, issued: daysAgo(36), terms: 14, status: .paid, items: [("Photo retouching, 40 images", 40, 18)]),
            Spec(number: 11, client: nordwind, issued: daysAgo(26), terms: 14, status: .sent, items: [("Annual report layout", 1, 3600), ("Infographics", 5, 240)]),
            Spec(number: 12, client: acme, issued: daysAgo(17), terms: 14, status: .sent, items: [("Landing page design", 1, 1950)]),
            Spec(number: 13, client: bright, issued: daysAgo(9), terms: 30, status: .sent, items: [("Brand guidelines document", 1, 2100)], currency: .gbp),
            Spec(number: 14, client: lichtwerk, issued: daysAgo(10), terms: 14, status: .draft, items: [("UX audit", 1, 1200)]),
            Spec(number: 15, client: nordwind, issued: daysAgo(0), terms: 14, status: .draft, items: [("Newsletter template", 1, 650), ("Icon set", 20, 25)]),
        ]
        let year = calendar.component(.year, from: today)
        for spec in specs {
            var inv = Invoice(clientId: spec.client.id)
            inv.invoiceNumber = "\(profile.invoiceNumberPrefix)\(year)-\(String(format: "%04d", spec.number))"
            inv.issueDate = spec.issued
            inv.dueDate = days(spec.terms, after: spec.issued)
            inv.currency = spec.currency
            inv.createdAt = spec.issued
            inv.updatedAt = spec.issued
            inv.notes = spec.notes
            inv.lineItems = spec.items.map { LineItem(description: $0.0, quantity: $0.1, unitPrice: $0.2, vatRate: 19) }
            inv.status = spec.status
            switch spec.status {
            case .sent, .overdue:
                inv.sentAt = days(1, after: spec.issued)
            case .paid:
                inv.sentAt = days(1, after: spec.issued)
                inv.paidAt = days(spec.paidDaysAfter, after: spec.issued)
                if let rate = spec.rate {
                    inv.paidExchangeRate = rate
                    inv.paidAmountInBaseCurrency = inv.total * rate
                }
            default:
                break
            }
            context.insert(SDInvoice(from: inv, client: spec.client))
        }

        do {
            try context.save()
        } catch {
            Log.data.error("Demo seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#if os(macOS)
import AppKit

extension Notification.Name {
    /// Demo-only: advances onboarding one step so snapshots can show every screen.
    static let snapshotAdvanceOnboarding = Notification.Name("mira.snapshot.advanceOnboarding")
}

/// `MIRA_SNAPSHOT=/path/to/dir` renders the main window to PNG files for
/// each section and quits. Pair it with `MIRA_DEMO=1` for sample data, and
/// `MIRA_ONBOARDING=1` to capture the setup flow instead.
enum SnapshotRunner {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["MIRA_SNAPSHOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    @MainActor
    static func runIfRequested() {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if ProcessInfo.processInfo.environment["MIRA_ONBOARDING"] == "1" {
                capture("onboarding-welcome", to: directory)
                for step in ["business", "address", "tax", "bank", "branding", "appearance", "done", "finished"] {
                    NotificationCenter.default.post(name: .snapshotAdvanceOnboarding, object: nil)
                    try? await Task.sleep(for: .seconds(1.0))
                    capture("onboarding-\(step)", to: directory)
                }
            } else {
                for (name, target) in [("overview", "dashboard"), ("invoices", "invoices"), ("clients", "clients")] {
                    NotificationCenter.default.post(name: .navigateTo, object: target)
                    try? await Task.sleep(for: .seconds(1.5))
                    capture(name, to: directory)
                }
                NotificationCenter.default.post(name: .navigateTo, object: "settings")
                try? await Task.sleep(for: .seconds(1.5))
                let settingsWindow = NSApp.windows.first(where: { $0.title.localizedCaseInsensitiveContains("settings") || $0.title.localizedCaseInsensitiveContains("general") })
                capture("settings", to: directory, window: settingsWindow)
                settingsWindow?.close()
                try? await Task.sleep(for: .seconds(0.5))
                NotificationCenter.default.post(name: .newInvoice, object: nil)
                try? await Task.sleep(for: .seconds(1.5))
                capture("new-invoice", to: directory, preferSheet: true)
            }
            exit(0)
        }
    }

    @MainActor
    private static func capture(_ name: String, to directory: URL, preferSheet: Bool = false, window preferred: NSWindow? = nil) {
        let windows = NSApp.windows.filter { $0.isVisible }
        let window = preferred
            ?? (preferSheet ? windows.first(where: { $0.sheetParent != nil }) : nil)
            ?? NSApp.keyWindow ?? windows.first
        guard let window, let content = window.contentView, let frameView = content.superview else { return }
        let rect = frameView.bounds
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: rect) else { return }
        frameView.cacheDisplay(in: rect, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try data.write(to: directory.appendingPathComponent("\(name).png"))
        } catch {
            Log.app.error("Snapshot write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

}
#endif
