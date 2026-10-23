import Foundation
import Sparkle

/// Updates of the GitHub download through Sparkle (ADR 0016).
///
/// Sparkle refuses an update it cannot check against the public EdDSA key in `Info.plist`
/// (`SUPublicEDKey`), so the updater starts only once that key is there (`docs/RELEASE.md`).
@MainActor
final class Updater {
    private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        controller =
            key?.isEmpty == false
            ? SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
