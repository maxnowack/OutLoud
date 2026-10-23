import OutloudKit
import SwiftUI

/// The kept results, newest first (`docs/DESIGN.md` §"HistoryList").
public struct HistoryList: View {
    let history: HistoryModel
    let period: RetentionPeriod
    @Binding var selection: HistoryEntry.ID?

    public init(
        history: HistoryModel, period: RetentionPeriod, selection: Binding<HistoryEntry.ID?>
    ) {
        self.history = history
        self.period = period
        self._selection = selection
    }

    public var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView {
                    Label(localized("No results kept"), systemImage: "clock")
                } description: {
                    Text(
                        period == .nothing
                            ? localized(
                                "Outloud keeps no results. You can change this in the settings.")
                            : localized("Results are kept for \(period.title).")
                    )
                }
            } else {
                List(selection: $selection) {
                    ForEach(history.entries) { entry in
                        HistoryRow(entry: entry)
                            .tag(entry.id)
                            .contextMenu {
                                Button(localized("Copy")) { Clipboard.copy(entry.result) }
                                Button(localized("Delete"), role: .destructive) {
                                    Task { await history.delete(entry) }
                                }
                            }
                    }
                    .onDelete { offsets in
                        let entries = offsets.map { history.entries[$0] }
                        Task { for entry in entries { await history.delete(entry) } }
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(spacing: Tokens.Spacing.xs) {
                Text(entry.createdAt, format: .dateTime.day().month().hour().minute())
                if entry.hasAudio {
                    Image(systemName: "speaker.wave.2")
                        .accessibilityLabel(localized("With audio"))
                }
            }
            .font(Tokens.caption)
            .foregroundStyle(Tokens.textSecondary)
            Text(entry.result)
                .font(Tokens.body)
                .lineLimit(2)
        }
        .padding(.vertical, Tokens.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// One kept result: its audio, the cleaned version and the transcript
/// (`docs/DESIGN.md` §"HistoryEntryDetail").
public struct HistoryEntryDetail: View {
    let entry: HistoryEntry
    let history: HistoryModel

    public init(entry: HistoryEntry, history: HistoryModel) {
        self.entry = entry
        self.history = history
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                Text(
                    entry.createdAt,
                    format: .dateTime.weekday().day().month().year().hour().minute()
                )
                .font(Tokens.caption)
                .foregroundStyle(Tokens.textSecondary)
                if entry.hasAudio {
                    AudioPlayer(entry: entry, history: history)
                }
                if let cleaned = entry.cleaned {
                    section(title: localized("Cleaned up"), text: cleaned)
                }
                section(title: localized("Transcript"), text: entry.transcript)
            }
            .padding(Tokens.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear { history.stop() }
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            HStack {
                Text(title).font(Tokens.heading)
                Spacer()
                Button {
                    Clipboard.copy(text)
                    announce(localized("Copied"))
                } label: {
                    Label(localized("Copy"), systemImage: "doc.on.doc")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(localized("Copy \(title)"))
            }
            Text(text)
                .font(Tokens.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Tokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusMedium))
        }
    }
}

/// The retention periods (`docs/DESIGN.md` §"RetentionPicker").
public struct RetentionPicker: View {
    @Binding var period: RetentionPeriod

    public init(period: Binding<RetentionPeriod>) {
        self._period = period
    }

    public var body: some View {
        Picker(localized("Keep results for"), selection: $period) {
            ForEach(RetentionPeriod.allCases, id: \.self) { period in
                Text(period.title).tag(period)
            }
        }
    }
}
