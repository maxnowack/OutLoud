import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// The design tokens of `docs/DESIGN.md` §"Tokens". Screens and components use these, never
/// literals.
public enum Tokens {
    // MARK: Colour

    public static let accent = Color(light: 0x1F7A70, dark: 0x4CC2B2)
    /// Filled surfaces with white content — the record button, prominent buttons: the app icon's
    /// colour in both appearances, where white keeps its contrast.
    public static let accentFill = Color(light: 0x1F7A70, dark: 0x1F7A70)
    public static let recording = Color.red
    public static let success = Color.green
    public static let warning = Color.orange
    public static let failure = Color.red
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    #if os(macOS)
        public static let surface = Color(nsColor: .controlBackgroundColor)
    #else
        public static let surface = Color(uiColor: .secondarySystemBackground)
    #endif

    // MARK: Typography

    public static let title = Font.title2.weight(.semibold)
    public static let heading = Font.headline
    public static let body = Font.body
    public static let detail = Font.callout
    public static let caption = Font.caption

    // MARK: Spacing

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    // MARK: Shape

    public static let radiusSmall: CGFloat = 6
    public static let radiusMedium: CGFloat = 10
    public static let radiusLarge: CGFloat = 16
    public static let recordButtonSize: CGFloat = 104
    public static let playButtonSize: CGFloat = 56
    public static let waveformHeight: CGFloat = 36
    public static let confirmationIconSize: CGFloat = 64
    /// The StatusIndicator's icon, and its progress ring, which holds the seconds left of two
    /// digits.
    public static let statusIconSize: CGFloat = 20
    public static let progressRingSize: CGFloat = 24
    /// The LevelWave while recording: the overlay's on the Mac, larger on the iPhone's Dictate tab.
    #if os(macOS)
        public static let levelWaveSize = CGSize(width: 96, height: 24)
    #else
        public static let levelWaveSize = CGSize(width: 180, height: 44)
    #endif

    // MARK: Elevation

    /// The macOS recording overlay is a Liquid Glass capsule, which brings its own depth; its
    /// text wraps at this width.
    public static let overlayTextWidth: CGFloat = 320
    /// The transparent area the overlay's panel takes at the bottom of the screen; the capsule
    /// moves and grows inside it.
    public static let overlayAreaSize = CGSize(width: 640, height: 160)
    /// The height of the capsule's middle above the bottom of the visible screen, the same for
    /// every content: a taller capsule grows as far down as up. It is where the middle of the
    /// recording capsule stood while capsules shared their bottom edge.
    public static let overlayMidlineHeight: CGFloat = 114

    // MARK: Motion

    public static let standard = Animation.easeInOut(duration: 0.2)
    public static let pulse = Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
    /// The macOS recording overlay growing and fading in, and fading out; without a bounce, which
    /// made the glass wobble.
    public static let overlayAppear = Animation.smooth(duration: 0.4)
    public static let overlayFadeDuration: Duration = .milliseconds(400)
    /// How long the overlay's capsule takes to grow or shrink by `distance` points to the size of
    /// its next content, after the old one faded out and before the new one fades in: from
    /// 0.15 s for a few points to 0.3 s for the width of a label, so that a small change does
    /// not leave it empty for long.
    public static func overlayResizeSeconds(distance: CGFloat) -> Double {
        min(0.3, 0.15 + Double(distance) / 1000)
    }
    /// The overlay's content fading out before the capsule changes size, and in after.
    public static let overlayContentFade = Animation.easeInOut(duration: 0.12)
    public static let overlayContentFadeDuration: Duration = .milliseconds(120)
    /// Up to this difference in width, the overlay swaps its content in a quick dip — out, and
    /// in while the capsule follows — instead of resizing it empty.
    public static let overlaySwapWidth: CGFloat = 12
    public static let overlaySwap = Animation.easeInOut(duration: 0.08)
    public static let overlaySwapDuration: Duration = .milliseconds(80)
    /// How long a step of the pipeline must last before the overlay shows it: a transcription
    /// on the Mac often takes less, and a step shown for less than its own transition is never
    /// read.
    public static let overlayStepHold: Duration = .milliseconds(250)
}

extension Color {
    /// A colour with one value for the light and one for the dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
            self.init(
                nsColor: NSColor(name: nil) { appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        ? NSColor(hex: dark) : NSColor(hex: light)
                })
        #else
            self.init(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
                })
        #endif
    }
}

#if os(macOS)
    extension NSColor {
        fileprivate convenience init(hex: UInt32) {
            self.init(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
    }
#else
    extension UIColor {
        fileprivate convenience init(hex: UInt32) {
            self.init(
                red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
    }
#endif
