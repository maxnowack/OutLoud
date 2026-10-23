import AppIntents
import OutloudUI
import SwiftUI

/// Dictating from any app (`docs/SPEC.md` §"Dictation on iOS", ADR 0022): first the shortcut the
/// user sets up once, then the ways of running it, each with its steps and trade-offs, and last
/// the control that opens Outloud instead.
struct ShortcutGuide: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(Self.setupSteps.enumerated()), id: \.offset) { index, step in
                        NumberedStep(number: index + 1, text: step)
                    }
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                } header: {
                    Text("1. Set up the shortcut, once")
                } footer: {
                    Text(
                        "Run it once to start recording and again to stop. Outloud stays in the background, the Dynamic Island shows what is happening, and the text lands on the clipboard."
                    )
                }

                Section {
                    ForEach(Trigger.all) { trigger in
                        NavigationLink {
                            TriggerDetail(trigger: trigger)
                        } label: {
                            TriggerRow(trigger: trigger)
                        }
                    }
                } header: {
                    Text("2. Choose how to run it")
                }

                Section {
                    NavigationLink {
                        TriggerDetail(trigger: .openOutloud)
                    } label: {
                        TriggerRow(trigger: .openOutloud)
                    }
                } header: {
                    Text("Or open Outloud and record")
                } footer: {
                    Text("Needs no shortcut, but Outloud comes to the front.")
                }
            }
            .navigationTitle("Dictate from Any App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static var setupSteps: [LocalizedStringKey] {
        [
            "In the Shortcuts app, tap + to create a shortcut.",
            "Add the action Start or Stop Dictation with Outloud.",
            "Below it, add Copy to Clipboard.",
            "Name the shortcut, e.g. Dictate.",
        ]
    }
}

private struct NumberedStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.m) {
            Text("\(number)")
                .font(Tokens.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Tokens.accentFill, in: Circle())
            Text(text)
        }
    }
}

private struct TriggerRow: View {
    let trigger: Trigger

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs / 2) {
                Text(trigger.title).font(Tokens.heading)
                Text(trigger.summary)
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.textSecondary)
            }
        } icon: {
            Image(systemName: trigger.symbol).foregroundStyle(Tokens.accent)
        }
    }
}

private struct TriggerDetail: View {
    let trigger: Trigger

    var body: some View {
        List {
            Section("Set up") {
                ForEach(Array(trigger.steps.enumerated()), id: \.offset) { index, step in
                    NumberedStep(number: index + 1, text: step)
                }
            }
            Section("Good") {
                ForEach(Array(trigger.pros.enumerated()), id: \.offset) { Text($0.element) }
            }
            Section("Keep in mind") {
                ForEach(Array(trigger.cons.enumerated()), id: \.offset) { Text($0.element) }
            }
        }
        .navigationTitle(trigger.title)
    }
}

/// One way of running the shortcut — or, for `openOutloud`, of opening Outloud to record.
struct Trigger: Identifiable {
    let id: String
    let symbol: String
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let steps: [LocalizedStringKey]
    let pros: [LocalizedStringKey]
    let cons: [LocalizedStringKey]

    static var all: [Trigger] {
        [
            Trigger(
                id: "assistive-touch", symbol: "circle.circle", title: "AssistiveTouch",
                summary: "A small button on the screen, one tap",
                steps: [
                    "Open Settings › Accessibility › Touch › AssistiveTouch and switch it on.",
                    "Under Custom Actions, set Single-Tap to your shortcut.",
                    "Set Idle Opacity to about 15 %, so that the button stays out of the way.",
                    "Optional: under Settings › Accessibility › Accessibility Shortcut, choose AssistiveTouch. A triple-click on the side button then shows or hides the button.",
                ],
                pros: [
                    "One tap, recognised every time.",
                    "Hidden with a triple-click when you do not need it.",
                ],
                cons: ["While it is on, a small button lies on the screen."]),
            Trigger(
                id: "action-button", symbol: "button.vertical.left.press",
                title: "Action Button",
                summary: "One press, also with the iPhone locked",
                steps: [
                    "Open Settings › Action Button.",
                    "Swipe to Shortcut and choose your shortcut.",
                ],
                pros: ["A button you can feel, in any app."],
                cons: [
                    "Only on iPhones with an Action Button.",
                    "Replaces what the button does now, e.g. the flashlight.",
                ]),
            Trigger(
                id: "back-tap", symbol: "hand.tap", title: "Back Tap",
                summary: "Tap the back of the iPhone",
                steps: [
                    "Open Settings › Accessibility › Touch › Back Tap.",
                    "Choose Double Tap or Triple Tap and pick your shortcut.",
                ],
                pros: ["No button needed, on every iPhone."],
                cons: [
                    "Not always recognised, above all through a thick case.",
                    "Can start by accident, e.g. when you put the iPhone down.",
                ]),
            Trigger(
                id: "control-center", symbol: "switch.2", title: "Control Center",
                summary: "Swipe down, tap",
                steps: [
                    "Swipe down from the top right corner.",
                    "Touch and hold an empty space, then tap Add a Control.",
                    "Choose Shortcuts › Run Shortcut, then your shortcut.",
                ],
                pros: ["On every iPhone, in every app."],
                cons: ["Two steps: swipe down, then tap."]),
            Trigger(
                id: "siri", symbol: "mic.badge.plus", title: "Siri",
                summary: "Say the shortcut's name",
                steps: ["Say “Hey Siri” and the name of your shortcut, e.g. “Dictate”."],
                pros: ["Hands-free."],
                cons: ["You speak out loud before dictating; Siri must be on."]),
        ]
    }

    static var openOutloud: Trigger {
        Trigger(
            id: "open-outloud", symbol: "arrow.up.forward.app", title: "Outloud's Dictate control",
            summary: "Opens Outloud and starts recording",
            steps: [
                "Open Settings › Action Button, swipe to Controls and choose Outloud › Dictate.",
                "Or add Outloud › Dictate to the Control Center or the Lock Screen: touch and hold an empty space, then tap Add a Control.",
            ],
            pros: ["Works without setting up a shortcut."],
            cons: ["Outloud comes to the front; you switch back to paste."])
    }
}
