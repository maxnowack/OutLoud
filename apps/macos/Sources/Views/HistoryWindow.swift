import OutloudKit
import OutloudUI
import SwiftUI

/// The history window (`docs/DESIGN.md` §"Screens": macOS history window).
struct HistoryWindow: View {
    let app: AppModel
    @State private var selection: HistoryEntry.ID?

    var body: some View {
        NavigationSplitView {
            HistoryList(
                history: app.history, period: app.settings.retentionPeriod, selection: $selection
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let entry = app.history.entries.first(where: { $0.id == selection }) {
                HistoryEntryDetail(entry: entry, history: app.history)
            } else {
                ContentUnavailableView("Select a result", systemImage: "text.quote")
            }
        }
        .task { await app.history.refresh() }
    }
}
