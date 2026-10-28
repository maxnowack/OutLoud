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

    func bind(to dictation: DictationController, pauser: PlaybackPauser) {
        model.dictation = dictation
        model.pauser = pauser
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
        model.delivery = delivery
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
    var pauser: PlaybackPauser?
    var delivery: AutoPaster.Delivery?
    var isVisible = false
}

/// What the pill shows: a state of the dictation, or how its result was delivered.
private enum PillContent: Equatable {
    case status(DictationState)
    case delivery(AutoPaster.Delivery)
}

private struct OverlayView: View {
    let model: OverlayModel
    /// The content on display, which follows the model's in three steps — fade out, resize, fade
    /// in — so that the capsule never holds content that spills over its edge or space that a
    /// content does not fill.
    @State private var shown: PillContent?
    @State private var contentVisible = true
    /// The width of `shown`'s content, and of the target's, measured beside it unseen.
    @State private var shownWidth: CGFloat = 0
    @State private var targetWidth = Measured(content: nil, width: 0)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.isVisible {
                pill.transition(appearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(Tokens.Spacing.m)
        .task(id: Change(target: target, isVisible: model.isVisible)) { await follow() }
    }

    private struct Change: Equatable {
        let target: PillContent?
        let isVisible: Bool
    }

    private struct Measured: Equatable {
        let content: PillContent?
        let width: CGFloat
    }

    /// The content the model asks for.
    private var target: PillContent? {
        if let delivery = model.delivery { return .delivery(delivery) }
        return model.dictation.map { .status($0.state) }
    }

    /// Brings `shown` to `target`: at once while the pill is hidden, otherwise by fading the old
    /// content out, letting the capsule take the new one's size, and fading it in — or, where
    /// the two are about as wide, in a quick dip; a narrower one fades in while the capsule
    /// shrinks around it, so that "Pasted" comes with the pasted text. A step of the pipeline is shown only once it
    /// lasted `overlayStepHold`, so that one that ends sooner is skipped. A change that comes in
    /// between starts over from where the pill stands.
    private func follow() async {
        guard let target else { return }
        guard model.isVisible, shown != nil else {
            shown = target
            contentVisible = true
            return
        }
        // The delivery follows the result at once, after the paste; "Done" before it would only
        // flash. The step before stays, its ring full.
        guard target != shown, !Self.isResult(target) else {
            withAnimation(Tokens.overlayContentFade) { contentVisible = true }
            return
        }
        // Only while the pill shows something to read; an empty one goes on at once.
        if contentVisible, case .status(let state) = target, Self.passes(state) {
            try? await Task.sleep(for: Tokens.overlayStepHold)
            guard !Task.isCancelled else { return }
        }
        // Unmeasured, the target is treated as far off: the three steps never let it spill.
        let measured = targetWidth.content == target
        let distance = measured ? abs(targetWidth.width - shownWidth) : .infinity
        if distance <= Tokens.overlaySwapWidth {
            withAnimation(Tokens.overlaySwap) { contentVisible = false }
            try? await Task.sleep(for: Tokens.overlaySwapDuration)
            guard !Task.isCancelled else { return }
            withAnimation(Tokens.overlaySwap) {
                shown = target
                contentVisible = true
            }
            return
        }
        let resize = Tokens.overlayResizeSeconds(distance: distance)
        // A narrower content already fits the capsule: it cannot spill while the capsule shrinks.
        if measured, targetWidth.width < shownWidth {
            withAnimation(Tokens.overlaySwap) { contentVisible = false }
            try? await Task.sleep(for: Tokens.overlaySwapDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: resize)) { shown = target }
            withAnimation(Tokens.overlayContentFade) { contentVisible = true }
            return
        }
        withAnimation(Tokens.overlayContentFade) { contentVisible = false }
        try? await Task.sleep(for: Tokens.overlayContentFadeDuration)
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: resize)) { shown = target }
        try? await Task.sleep(for: .seconds(resize))
        guard !Task.isCancelled else { return }
        withAnimation(Tokens.overlayContentFade) { contentVisible = true }
    }

    /// Whether a state gives way to another by itself: the steps of the pipeline.
    private static func passes(_ state: DictationState) -> Bool {
        switch state {
        case .transcribing, .cleaning: true
        case .idle, .recording, .finished, .failed: false
        }
    }

    private static func isResult(_ content: PillContent) -> Bool {
        if case .status(.finished) = content { true } else { false }
    }

    private var pill: some View {
        let target = target
        return content(of: shown ?? target)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                shownWidth = $0
            }
            .opacity(contentVisible ? 1 : 0)
            .background {
                content(of: target)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: Measured.self) {
                        Measured(content: target, width: $0.size.width)
                    } action: {
                        targetWidth = $0
                    }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.vertical, Tokens.Spacing.m)
            // Nothing reaches past the capsule while it changes size.
            .clipShape(.capsule)
            .background(GlassCapsule())
            .fixedSize()
    }

    private func content(of content: PillContent?) -> some View {
        HStack(spacing: Tokens.Spacing.m) {
            switch content {
            case .delivery(let delivery):
                let succeeded = delivery == .pasted
                Image(systemName: Self.symbol(for: delivery))
                    .foregroundStyle(succeeded ? Tokens.success : Tokens.accent)
                Text(Self.message(for: delivery))
                    .font(Tokens.detail)
                    .lineLimit(2)
                    .frame(maxWidth: Tokens.overlayTextWidth)
                    .fixedSize(horizontal: false, vertical: true)
            case .status(let state):
                // A step still shown after the dictation moved on is complete: its ring full, the
                // line flat, rather than the next step's values.
                let isLive = state == model.dictation?.state
                VStack(spacing: Tokens.Spacing.xs) {
                    StatusIndicator(
                        state: state, progress: isLive ? model.dictation?.progress : 1,
                        secondsLeft: isLive ? model.dictation?.secondsLeft : nil,
                        voice: model.dictation?.voice)
                    // What still sounds after the pause command, which the microphone may pick
                    // up (ADR 0025).
                    if state == .recording, model.pauser?.hearsBackgroundAudio == true {
                        Label(
                            "Something is playing in the background",
                            systemImage: "speaker.wave.2.fill"
                        )
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.warning)
                        .transition(.opacity)
                    }
                }
                if case .failed(let failure) = state {
                    Text(FailureNotice.message(for: failure))
                        .font(Tokens.caption)
                        .lineLimit(2)
                }
            case nil:
                EmptyView()
            }
        }
    }

    /// Grows out of a smaller capsule while fading in, and shrinks a little while fading out;
    /// with Reduce Motion it only fades.
    private var appearance: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.6).combined(with: .opacity),
                removal: .scale(scale: 0.85).combined(with: .opacity))
    }

    private static func symbol(for delivery: AutoPaster.Delivery) -> String {
        switch delivery {
        case .pasted: "checkmark.circle.fill"
        case .waiting: "clock.fill"
        case .copied: "doc.on.clipboard"
        }
    }

    static func message(for delivery: AutoPaster.Delivery) -> String {
        switch delivery {
        case .pasted: String(localized: "Pasted")
        case .waiting(let app):
            String(localized: "Pastes into \(app) when you are back in the text field.")
        case .copied(.noPermission):
            String(localized: "Copied — press ⌘V. Allow Accessibility to paste automatically.")
        case .copied(.noTextField): String(localized: "Copied — press ⌘V where you want the text.")
        case .copied(.autoPasteOff): String(localized: "Copied — press ⌘V.")
        }
    }
}

/// Liquid Glass as a capsule, in its clear style. The regular style, AppKit's as SwiftUI's, turns
/// into an even fill over a calm background — a desktop, a page —, so the pill looked like a
/// plain one; the clear style lets what lies behind show through and shines at the edge, as the
/// user chose from a side-by-side comparison (`plans/TRANSCRIPTION_PROGRESS.md` §"Status").
private struct GlassCapsule: NSViewRepresentable {
    func makeNSView(context: Context) -> CapsuleGlassView {
        let view = CapsuleGlassView()
        view.style = .clear
        return view
    }

    func updateNSView(_ view: CapsuleGlassView, context: Context) {}
}

/// Keeps the corners at half the height while SwiftUI resizes it.
private final class CapsuleGlassView: NSGlassEffectView {
    override func layout() {
        super.layout()
        cornerRadius = bounds.height / 2
    }
}
