import Foundation
import SwiftUI
import Sparkle
import Combine

/// Manages app updates via Sparkle
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()
    
    private var updaterController: SPUStandardUpdaterController?
    
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    
    var updater: SPUUpdater? {
        updaterController?.updater
    }
    
    private init() {
        // Delay Sparkle initialization to avoid blocking app startup
        DispatchQueue.main.async { [weak self] in
            self?.setupSparkle()
        }
    }
    
    private func setupSparkle() {
        // Create the updater controller
        // The updater will use the SUFeedURL from Info.plist
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        guard let updater = updaterController?.updater else { return }
        
        // Observe canCheckForUpdates
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
        
        // Check for updates on startup (after a short delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkForUpdatesOnStartup()
        }
    }
    
    /// Check for updates on app startup - only shows UI if update is available
    private func checkForUpdatesOnStartup() {
        guard let updater = updaterController?.updater, updater.canCheckForUpdates else { return }
        
        // Use checkForUpdatesInBackground which silently checks and only shows UI if update found
        updater.checkForUpdatesInBackground()
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
    
    /// Get the current app version
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    /// Get the current build number
    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}

/// SwiftUI view for the "Check for Updates" menu item
struct CheckForUpdatesView: View {
    @ObservedObject private var updaterManager = UpdaterManager.shared
    
    var body: some View {
        Button("Check for Updates…") {
            updaterManager.checkForUpdates()
        }
        .disabled(!updaterManager.canCheckForUpdates)
    }
}
