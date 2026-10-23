import AppIntents
import SwiftUI
import WidgetKit

@main
struct OutloudWidgets: WidgetBundle {
    var body: some Widget {
        DictateControl()
        DictationLiveActivity()
    }
}

/// The control the Action Button, the Control Center and the Lock Screen offer (ADR 0017).
struct DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.nowack.outloud.dictate") {
            ControlWidgetButton(action: StartDictationIntent()) {
                Label("Dictate", systemImage: "mic.fill")
            }
        }
        .displayName("Dictate with Outloud")
        .description("Opens Outloud and starts recording.")
    }
}
