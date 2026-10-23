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
    /// The cleanup's progress bar beside the status.
    public static let progressBarWidth: CGFloat = 64

    // MARK: Elevation

    /// The macOS recording overlay is a Liquid Glass capsule, which brings its own depth; its
    /// text wraps at this width.
    public static let overlayTextWidth: CGFloat = 320

    // MARK: Motion

    public static let standard = Animation.easeInOut(duration: 0.2)
    public static let pulse = Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
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
