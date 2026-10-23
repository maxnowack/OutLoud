import AppIntents
import OutloudUI
import SwiftUI

/// The ways of starting a dictation without opening Outloud first, each with its steps and its
/// trade-offs (`docs/SPEC.md` §"Dictation on iOS").
struct ShortcutGuide: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "A shortcut that records and lets Outloud transcribe leaves you in your app. The other ways open Outloud and start recording at once."
                    )
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                }
                ForEach(Way.all) { way in
                    NavigationLink {
                        WayDetail(way: way)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xs / 2) {
                                Text(way.title).font(Tokens.heading)
                                Text(way.summary)
                                    .font(Tokens.caption)
                                    .foregroundStyle(Tokens.textSecondary)
                            }
                        } icon: {
                            Image(systemName: way.symbol).foregroundStyle(Tokens.accent)
                        }
                    }
                }
                Section {
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Start Outloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct WayDetail: View {
    let way: Way

    var body: some View {
        List {
            Section("Set up") {
                ForEach(Array(way.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.m) {
                        Text("\(index + 1)")
                            .font(Tokens.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Tokens.accent, in: Circle())
                        Text(step)
                    }
                }
            }
            Section("Good") {
                ForEach(Array(way.pros.enumerated()), id: \.offset) { Text($0.element) }
            }
            Section("Keep in mind") {
                ForEach(Array(way.cons.enumerated()), id: \.offset) { Text($0.element) }
            }
        }
        .navigationTitle(way.title)
    }
}

/// One way of starting a dictation.
struct Way: Identifiable {
    let id: String
    let symbol: String
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let steps: [LocalizedStringKey]
    let pros: [LocalizedStringKey]
    let cons: [LocalizedStringKey]

    static var all: [Way] {
        [
            Way(
                id: "any-app", symbol: "waveform.badge.mic", title: "In any app",
                summary: "Record, transcribe, copy — Outloud stays closed",
                steps: [
                    "In the Shortcuts app, create a shortcut and add Record Audio. Set it to start immediately and to finish on tap.",
                    "Add Transcribe Audio with Outloud, then Copy to Clipboard.",
                    "Run it with Back Tap, the Action Button (Shortcut) or Siri.",
                ],
                pros: [
                    "You stay in the app you are writing in.",
                    "The microphone is open only while you record.",
                ],
                cons: ["Set up once in the Shortcuts app."]),
            Way(
                id: "action", symbol: "button.vertical.left.press", title: "Action Button",
                summary: "One press, also on the Lock Screen",
                steps: [
                    "Open Settings › Action Button.",
                    "Swipe to Controls and tap Choose a Control.",
                    "Search for Outloud and choose Dictate.",
                ],
                pros: ["One press from anywhere, even with the iPhone locked."],
                cons: [
                    "Only on iPhones with an Action Button.",
                    "Replaces what the button does now, e.g. silent mode.",
                ]),
            Way(
                id: "control-center", symbol: "switch.2", title: "Control Center",
                summary: "Swipe down, tap",
                steps: [
                    "Swipe down from the top right corner.",
                    "Touch and hold an empty space, then tap Add a Control.",
                    "Search for Outloud and choose Dictate.",
                ],
                pros: ["Works on every iPhone, in every app."],
                cons: ["Two steps: swipe down, then tap."]),
            Way(
                id: "lock-screen", symbol: "lock.iphone", title: "Lock Screen",
                summary: "A button at the bottom of the Lock Screen",
                steps: [
                    "Touch and hold the Lock Screen, then tap Customize › Lock Screen.",
                    "Remove the flashlight or the camera control at the bottom.",
                    "Tap the plus and choose Outloud › Dictate.",
                ],
                pros: ["Ready before you unlock the iPhone."],
                cons: ["Takes the place of the flashlight or the camera."]),
            Way(
                id: "back-tap", symbol: "hand.tap", title: "Back Tap",
                summary: "Tap the back of the iPhone twice",
                steps: [
                    "Set up the shortcut from In any app.",
                    "Open Settings › Accessibility › Touch › Back Tap.",
                    "Choose Double Tap and pick that shortcut.",
                ],
                pros: ["No button needed; works on every iPhone and leaves you in your app."],
                cons: ["Can start by accident, e.g. when putting the iPhone down."]),
            Way(
                id: "siri", symbol: "mic.badge.plus", title: "Siri",
                summary: "Say “Dictate with Outloud”",
                steps: ["Say “Hey Siri, dictate with Outloud”."],
                pros: ["Hands-free."],
                cons: ["You speak out loud before dictating; Siri must be on."]),
            Way(
                id: "home-screen", symbol: "apps.iphone", title: "Home Screen",
                summary: "An icon next to your apps",
                steps: [
                    "Open the Shortcuts app and find Outloud › Dictate.",
                    "Touch and hold it, then choose Add to Home Screen.",
                ],
                pros: ["Easy to find and to explain to others."],
                cons: ["Only from the Home Screen, with the iPhone unlocked."]),
        ]
    }
}
