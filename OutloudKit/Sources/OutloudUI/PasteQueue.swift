import SwiftUI

/// The dictations that wait to be pasted, with their copy and remove buttons (`docs/DESIGN.md`
/// §"PasteQueue").
public struct PasteQueue<ID: Hashable>: View {
    /// One dictation that waits.
    public struct Item: Identifiable, Equatable {
        public let id: ID
        /// The app whose field it goes into; `nil` for the next text field focused.
        public let app: String?
        /// The result; `nil` while the dictation is processed.
        public let text: String?

        public init(id: ID, app: String?, text: String?) {
            self.id = id
            self.app = app
            self.text = text
        }
    }

    private struct Row: Identifiable {
        let item: Item
        let copied: Bool
        var id: ID { item.id }
    }

    let items: [Item]
    /// Takes a dictation out of the queue: copied, or not to be pasted.
    let remove: (Item) -> Void
    /// The dictation copied last and its place, kept for two seconds to confirm the copy.
    @State private var copied: (item: Item, index: Int)?

    public init(items: [Item], remove: @escaping (Item) -> Void) {
        self.items = items
        self.remove = remove
    }

    public var body: some View {
        let rows = self.rows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Text(localized("Waiting to paste"))
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                ForEach(rows) { row in
                    PasteQueueRow(
                        app: row.item.app, text: row.item.text, copied: row.copied,
                        copy: { copy(row.item) }, remove: { remove(row.item) })
                }
            }
        }
    }

    private var rows: [Row] {
        var rows = items.map { Row(item: $0, copied: false) }
        if let copied, !items.contains(where: { $0.id == copied.item.id }) {
            rows.insert(Row(item: copied.item, copied: true), at: min(copied.index, rows.count))
        }
        return rows
    }

    private func copy(_ item: Item) {
        guard let text = item.text else { return }
        Clipboard.copy(text)
        announce(localized("Copied"))
        copied = (item, items.firstIndex(of: item) ?? items.count)
        remove(item)
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copied?.item.id == item.id { copied = nil }
        }
    }
}

private struct PasteQueueRow: View {
    let app: String?
    let text: String?
    let copied: Bool
    let copy: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Label {
                    Text(target)
                } icon: {
                    Image(systemName: "clock").foregroundStyle(Tokens.accent)
                }
                .font(Tokens.caption)
                .foregroundStyle(Tokens.textSecondary)
                if let text {
                    Text(text)
                        .font(Tokens.body)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: Tokens.Spacing.s) {
                        ProgressView().controlSize(.small)
                        Text(localized("Processing…"))
                    }
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            HStack {
                Spacer()
                if copied {
                    Label(localized("Copied"), systemImage: "checkmark")
                        .font(Tokens.detail)
                        .foregroundStyle(Tokens.success)
                } else {
                    if text != nil {
                        Button(action: copy) {
                            Label(localized("Copy"), systemImage: "doc.on.doc")
                        }
                        .help(localized("Copies the text. Outloud no longer pastes it."))
                    }
                    Button(action: remove) {
                        Label(localized("Don't Paste"), systemImage: "xmark")
                    }
                    .help(localized("Outloud no longer pastes the text. It stays in the history."))
                }
            }
            .controlSize(.small)
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusMedium))
    }

    private var target: String {
        app.map { localized("Into \($0)") } ?? localized("Into the next text field")
    }
}
