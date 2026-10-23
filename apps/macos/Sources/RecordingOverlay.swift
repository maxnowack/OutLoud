import AppKit
import Observation
import OutloudKit
import OutloudUI
import SwiftUI

/// The small floating pill that shows recording and processing while the hotkey is used
/// (`docs/DESIGN.md` §"Screens": macOS recording overlay). The panel takes the pill's size and
/// stays centred at the bottom of the screen as the pill grows and shrinks.
///
/// The panel never becomes key or active, so the app the user is typing in keeps the focus and
/// receives the paste.
@MainActor
final class RecordingOverlay {
    private let panel: NSPanel
    private let model = OverlayModel()
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 64),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        model.onResize = { [weak self] size in self?.resize(to: size) }
    }

    func bind(to dictation: DictationController) {
        model.dictation = dictation
    }

    func show() {
        hideTask?.cancel()
        model.delivery = nil
        position()
        panel.orderFrontRegardless()
    }

    /// Shows the current state — a failure, say — for a moment.
    func showBriefly() {
        show()
        hide(after: .seconds(3))
    }

    func showDelivery(_ delivery: AutoPaster.Delivery) {
        model.delivery = delivery
        position()
        panel.orderFrontRegardless()
        hide(after: .seconds(delivery == .pasted ? 1 : 3))
    }

    func hide(after delay: Duration = .zero) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
            self?.model.dictation?.reset()
        }
    }

    private func resize(to size: CGSize) {
        guard size != panel.frame.size, size.width > 0, size.height > 0 else { return }
        panel.setContentSize(size)
        position()
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 80))
    }
}

@MainActor
@Observable
final class OverlayModel {
    var dictation: DictationController?
    var delivery: AutoPaster.Delivery?
    /// Called with the pill's size whenever its content changes it.
    @ObservationIgnored var onResize: ((CGSize) -> Void)?
}

private struct OverlayView: View {
    let model: OverlayModel

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            if let delivery = model.delivery {
                Image(
                    systemName: delivery == .pasted ? "checkmark.circle.fill" : "doc.on.clipboard"
                )
                .foregroundStyle(delivery == .pasted ? Tokens.success : Tokens.accent)
                Text(Self.message(for: delivery))
                    .font(Tokens.detail)
                    .lineLimit(2)
                    .frame(maxWidth: Tokens.overlayTextWidth)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let dictation = model.dictation {
                StatusIndicator(state: dictation.state, progress: dictation.cleanupProgress)
                if dictation.state == .recording {
                    LevelMeter(level: dictation.level)
                }
                if case .failed(let failure) = dictation.state {
                    Text(FailureNotice.message(for: failure))
                        .font(Tokens.caption)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .padding(.vertical, Tokens.Spacing.m)
        .glassEffect(.regular, in: .capsule)
        // Room for the glass's own shadow inside the panel.
        .padding(Tokens.Spacing.m)
        .fixedSize()
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            model.onResize?($0)
        }
    }

    static func message(for delivery: AutoPaster.Delivery) -> String {
        switch delivery {
        case .pasted: String(localized: "Pasted")
        case .copied(.noPermission):
            String(localized: "Copied — press ⌘V. Allow Accessibility to paste automatically.")
        case .copied(.noTextField): String(localized: "Copied — press ⌘V where you want the text.")
        case .copied(.autoPasteOff): String(localized: "Copied — press ⌘V.")
        }
    }
}
