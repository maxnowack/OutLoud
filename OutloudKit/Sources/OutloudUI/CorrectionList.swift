import OutloudKit
import SwiftUI

/// The user's corrections in the settings of both apps (`docs/DESIGN.md` §"CorrectionList";
/// `docs/SPEC.md` §"Corrections"): a form to add one, and the list, newest first, each with its
/// origin and how often it corrected a result. Sections of a `Form`.
public struct CorrectionList: View {
    let store: CorrectionStore
    @State private var heard = ""
    @State private var meant = ""
    @State private var problem: CorrectionError?
    @FocusState private var focus: Field?

    private enum Field { case heard, meant }

    public init(store: CorrectionStore) {
        self.store = store
    }

    public var body: some View {
        Section {
            TextField(localized("Heard as"), text: $heard, prompt: Text(localized("out loud")))
                .focused($focus, equals: .heard)
                .onSubmit { focus = .meant }
            TextField(localized("Write as"), text: $meant, prompt: Text(localized("Outloud")))
                .focused($focus, equals: .meant)
                .onSubmit(add)
            if let problem {
                Label(message(for: problem), systemImage: "exclamationmark.circle")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.warning)
            }
            Button(localized("Add"), action: add)
                .disabled(meant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text(localized("Add a correction"))
        } footer: {
            Text(
                localized(
                    "Outloud writes what it heard as you write it, in every result. Leave “Heard as” empty to keep only a spelling."
                ))
        }
        #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #endif

        Section {
            if store.isUnreadable {
                Label(
                    localized(
                        "The corrections could not be read. Outloud leaves them as they are."),
                    systemImage: "exclamationmark.circle"
                )
                .font(Tokens.caption)
                .foregroundStyle(Tokens.warning)
            } else if store.corrections.isEmpty {
                Text(localized("No corrections yet"))
                    .foregroundStyle(Tokens.textSecondary)
            }
            ForEach(store.corrections) { correction in
                CorrectionRow(correction: correction) { delete(correction) }
            }
            #if os(iOS)
                .onDelete { offsets in offsets.map { store.corrections[$0] }.forEach(delete) }
            #endif
        } header: {
            Text(localized("Corrections"))
        } footer: {
            #if os(macOS)
                Text(
                    localized(
                        "When you change a word or two of a pasted dictation within 15 seconds, Outloud learns it."
                    ))
            #endif
        }
    }

    private func add() {
        do {
            try store.add(heard: heard, meant: meant, at: Date())
            heard = ""
            meant = ""
            problem = nil
            focus = .heard
            announce(localized("Correction added"))
        } catch let error as CorrectionError {
            problem = error
        } catch {
            problem = .unreadable
        }
    }

    private func delete(_ correction: Correction) {
        try? store.delete(correction.id)
    }

    private func message(for problem: CorrectionError) -> String {
        switch problem {
        case .invalid: localized("Use up to four words, without < or >.")
        case .duplicate: localized("This is already corrected.")
        case .full: localized("The list is full. Delete a correction first.")
        case .unreadable: localized("The corrections could not be saved.")
        }
    }
}

/// One correction: what was heard and what is written, or the spelling alone, with its origin and
/// use count below and, on the Mac, a Remove button (iOS deletes with a swipe).
private struct CorrectionRow: View {
    let correction: Correction
    let delete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(title)
                Text(detail)
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            #if os(macOS)
                Button(localized("Remove"), action: delete)
            #endif
        }
        .contextMenu {
            Button(localized("Remove"), systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private var title: String {
        guard let heard = correction.heard else { return correction.meant }
        return localized("\(heard) → \(correction.meant)")
    }

    private var detail: String {
        let uses =
            correction.uses == 0
            ? localized("Not used yet") : localized("Corrected \(correction.uses) times")
        return correction.origin == .learned ? localized("Learned · \(uses)") : uses
    }
}
