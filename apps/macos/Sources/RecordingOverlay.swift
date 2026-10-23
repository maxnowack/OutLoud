import AppKit
import Observation
import OutloudKit
import OutloudUI
import SwiftUI

/// The small floating pill that shows recording and processing while the hotkey is used
/// (`docs/DESIGN.md` §"Screens": macOS recording overlay).
///
/// The panel is a fixed, transparent area at the bottom of the screen, and the pill lives inside
/// it: SwiftUI fades it in and out and lets it grow and shrink smoothly with its content, which a
/// window resizing itself cannot. The panel never becomes key or active, so the app the user is
/// typing in keeps the focus and receives the paste; it ignores the mouse, so the transparent
/// area around the pill blocks nothing.
@MainActor
final class RecordingOverlay {
    private let panel: NSPanel
    private let model = OverlayModel()
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Tokens.overlayAreaSize),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
    }

    func bind(to dictation: DictationController) {
        model.dictation = dictation
    }

    func show() {
        model.delivery = nil
        present()
    }

    /// Shows the current state — a failure, say — for a moment.
    func showBriefly() {
        show()
        hide(after: .seconds(3))
    }

    func showDelivery(_ delivery: AutoPaster.Delivery) {
        withAnimation(Tokens.overlayResize) { model.delivery = delivery }
        present()
        hide(after: .seconds(delivery == .pasted ? 1 : 3))
    }

    /// Fades the pill out, then takes the panel away.
    func hide(after delay: Duration = .zero) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled, let self else { return }
            withAnimation(Tokens.overlayAppear) { self.model.isVisible = false }
            try? await Task.sleep(for: Tokens.overlayFadeDuration)
            guard !Task.isCancelled else { return }
            self.panel.orderOut(nil)
            self.model.dictation?.reset()
        }
    }

    private func present() {
        hideTask?.cancel()
        position()
        panel.orderFrontRegardless()
        withAnimation(Tokens.overlayAppear) { model.isVisible = true }
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let frame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(x: frame.midX - size.width / 2, y: frame.minY + Tokens.overlayBottomInset))
    }
}

@MainActor
@Observable
final class OverlayModel {
    var dictation: DictationController?
    var delivery: AutoPaster.Delivery?
    var isVisible = false
}

private struct OverlayView: View {
    let model: OverlayModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer {
            ZStack(alignment: .bottom) {
                if model.isVisible {
                    pill.transition(appearance)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(Tokens.Spacing.m)
        }
        // The panel is never key; without this the glass draws in its flat, inactive look.
        .environment(\.controlActiveState, .key)
    }

    private var pill: some View {
        HStack(spacing: Tokens.Spacing.m) {
            if let delivery = model.delivery {
                Image(
                    systemName: delivery == .pasted ? "checkmark.circle.fill" : "doc.on.clipboard"
                )
                .foregroundStyle(delivery == .pasted ? Tokens.success : Tokens.accent)
                .transition(.scale.combined(with: .opacity))
                Text(Self.message(for: delivery))
                    .font(Tokens.detail)
                    .lineLimit(2)
                    .frame(maxWidth: Tokens.overlayTextWidth)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let dictation = model.dictation {
                StatusIndicator(state: dictation.state, progress: dictation.cleanupProgress)
                if dictation.state == .recording {
                    LevelMeter(level: dictation.level)
                        .transition(.scale.combined(with: .opacity))
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
        .fixedSize()
        // The capsule grows and shrinks with its content instead of jumping.
        .animation(Tokens.overlayResize, value: model.dictation?.state)
        .animation(Tokens.overlayResize, value: model.delivery)
    }

    /// Rises a little while fading in, and settles back while fading out; with Reduce Motion it
    /// only fades.
    private var appearance: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.85, anchor: .bottom)
                    .combined(with: .offset(y: 12)).combined(with: .opacity),
                removal: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
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
