import OutloudKit
import SwiftUI

/// One model with its state and actions (`docs/DESIGN.md` §"ModelRow").
public struct ModelRow: View {
    let model: ModelDescriptor
    let library: ModelLibrary
    let network: NetworkMonitor
    @State private var confirmingDelete = false
    @State private var confirmingCellular = false
    @State private var deleteError: String?

    public init(model: ModelDescriptor, library: ModelLibrary, network: NetworkMonitor) {
        self.model = model
        self.library = library
        self.network = network
    }

    public var body: some View {
        let state = library.state(of: model)
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(model.displayName).font(Tokens.heading)
                    Text(
                        "\(model.purpose.title) · \(model.totalSize.formattedBytes) · \(model.languageSummary)"
                    )
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.textSecondary)
                }
                Spacer()
                actions(for: state)
            }
            switch state {
            case .downloading(let completed, let total):
                ProgressView(value: Double(completed), total: Double(max(total, 1))) {
                    Text(localized("\(completed.formattedBytes) of \(total.formattedBytes)"))
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.failure)
            default:
                EmptyView()
            }
            if let deleteError {
                Text(deleteError).font(Tokens.caption).foregroundStyle(Tokens.failure)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.displayName), \(Self.stateLabel(state))")
        .confirmationDialog(
            localized("Delete \(model.displayName)?"), isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(localized("Delete"), role: .destructive) {
                Task {
                    do { try await library.delete(model) } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(Self.deleteWarning(for: model))
        }
        .confirmationDialog(
            localized("Download over cellular data?"), isPresented: $confirmingCellular,
            titleVisibility: .visible
        ) {
            Button(localized("Download \(model.totalSize.formattedBytes)")) {
                library.download(model)
            }
        } message: {
            Text(
                localized(
                    "The model is large. Downloading it over cellular data may use up your data plan."
                ))
        }
    }

    @ViewBuilder private func actions(for state: ModelState) -> some View {
        switch state {
        case .notInstalled, .failed:
            Button(state == .notInstalled ? localized("Download") : localized("Retry")) {
                if network.isExpensive {
                    confirmingCellular = true
                } else {
                    library.download(model)
                }
            }
            .disabled(!network.isConnected)
        case .downloading:
            Button(localized("Stop")) { library.cancelDownload(model) }
        case .installed:
            HStack(spacing: Tokens.Spacing.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.success)
                    .accessibilityHidden(true)
                Button(localized("Delete"), role: .destructive) { confirmingDelete = true }
            }
        }
    }

    static func stateLabel(_ state: ModelState) -> String {
        switch state {
        case .notInstalled: localized("not downloaded")
        case .downloading: localized("downloading")
        case .installed: localized("downloaded")
        case .failed(let message): message
        }
    }

    static func deleteWarning(for model: ModelDescriptor) -> String {
        #if os(macOS)
            localized(
                "The model lies in the shared Hugging Face cache. Other apps and tools that use it will have to download it again, and so will Outloud before you use it again."
            )
        #else
            localized("Outloud will have to download the model again before you use it again.")
        #endif
    }
}
