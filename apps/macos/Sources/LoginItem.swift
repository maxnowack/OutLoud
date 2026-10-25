import Observation
import ServiceManagement

/// Opening Outloud at login, through the system's login items
/// (`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md`). It keeps no preference of its own: the system's
/// status is the truth, so the switch never disagrees with System Settings › Login Items.
@MainActor
@Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status
    /// The last change failed; macOS said no.
    private(set) var failed = false

    /// Whether Outloud opens at login, or will once the user approves it.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            failed = false
        } catch {
            failed = true
        }
        refresh()
    }

    /// Reads the status again; the user may have changed it in System Settings.
    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
