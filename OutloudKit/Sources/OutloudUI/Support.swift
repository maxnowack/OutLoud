import Foundation
import OutloudKit
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A string of this library, localised from its own string catalog.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

/// The system clipboard.
public enum Clipboard {
    public static func copy(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #else
            UIPasteboard.general.string = text
        #endif
    }
}

/// Announces a change to VoiceOver users.
func announce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension ModelPurpose {
    var title: String {
        switch self {
        case .transcription: localized("Transcription")
        case .cleanup: localized("Cleanup")
        }
    }

    var explanation: String {
        switch self {
        case .transcription: localized("Turns speech into text. Required.")
        case .cleanup:
            localized("Removes filler words, fixes punctuation and sets paragraphs. Optional.")
        }
    }
}

extension ModelDescriptor {
    var languageSummary: String {
        languages == ["multilingual"]
            ? localized("Multilingual")
            : localized("\(languages.count) languages, German and English among them")
    }
}

extension RetentionPeriod {
    public var title: String {
        switch self {
        case .nothing: localized("Nothing")
        case .oneDay: localized("1 day")
        case .threeDays: localized("3 days")
        case .tenDays: localized("10 days")
        case .thirtyDays: localized("30 days")
        case .threeMonths: localized("3 months")
        case .unlimited: localized("Unlimited")
        }
    }
}
