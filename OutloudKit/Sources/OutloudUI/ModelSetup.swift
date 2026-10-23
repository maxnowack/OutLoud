import OutloudKit
import SwiftUI

/// The first launch: choose or confirm the models and download them (`docs/SPEC.md` §"Models";
/// `docs/DESIGN.md` §"ModelSetup").
public struct ModelSetup: View {
    let library: ModelLibrary
    let settings: OutloudSettings
    let network: NetworkMonitor
    let finish: () -> Void
    @State private var started = false
    @State private var confirmingCellular = false
    @State private var missing: Int64 = 0

    public init(
        library: ModelLibrary, settings: OutloudSettings, network: NetworkMonitor,
        finish: @escaping () -> Void
    ) {
        self.library = library
        self.settings = settings
        self.network = network
        self.finish = finish
    }

    private var chosen: [ModelDescriptor] {
        settings.cleanupEnabled
            ? [settings.transcriptionModel, settings.cleanupModel] : [settings.transcriptionModel]
    }

    private var isReady: Bool { chosen.allSatisfy { library.state(of: $0).isInstalled } }
    private var isDownloading: Bool { chosen.contains { library.state(of: $0).isDownloading } }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Text(localized("Choose your models")).font(Tokens.title)
                Text(
                    localized(
                        "Outloud transcribes and cleans up on this device. It needs its models once; after that, nothing you say leaves the device."
                    )
                )
                .font(Tokens.body)
                .foregroundStyle(Tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                modelChoice(settings.transcriptionModel, required: true)
                modelChoice(settings.cleanupModel, required: false)
            }

            footer
        }
        .task { await updateMissing() }
        .onChange(of: settings.cleanupEnabled) { Task { await updateMissing() } }
        .onChange(of: library.states) { Task { await updateMissing() } }
        .confirmationDialog(
            localized("Download over cellular data?"), isPresented: $confirmingCellular,
            titleVisibility: .visible
        ) {
            Button(localized("Download \(missing.formattedBytes)")) { download() }
        } message: {
            Text(
                localized(
                    "The models are large. Downloading them over cellular data may use up your data plan."
                ))
        }
    }

    @ViewBuilder private func modelChoice(_ model: ModelDescriptor, required: Bool) -> some View {
        let state = library.state(of: model)
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            if required {
                Image(systemName: "checkmark.square.fill")
                    .foregroundStyle(Tokens.accent)
                    .accessibilityHidden(true)
            } else {
                Toggle(isOn: Bindable(settings).cleanupEnabled) { EmptyView() }
                    .labelsHidden()
                    .toggleStyle(CheckboxStyle())
                    .disabled(isDownloading)
                    .accessibilityLabel(localized("Use cleanup"))
            }
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text("\(model.purpose.title): \(model.displayName)").font(Tokens.heading)
                Text(model.purpose.explanation).font(Tokens.detail)
                Text("\(model.totalSize.formattedBytes) · \(model.languageSummary)")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.textSecondary)
                switch state {
                case .installed:
                    Label(localized("Already on this device"), systemImage: "checkmark.circle.fill")
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.success)
                case .downloading(let completed, let total):
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                    Text(localized("\(completed.formattedBytes) of \(total.formattedBytes)"))
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.failure)
                case .notInstalled:
                    EmptyView()
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            if !network.isConnected && !isReady {
                Label(localized("There is no internet connection."), systemImage: "wifi.slash")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.warning)
            } else if network.isExpensive && !isReady {
                Label(
                    localized("You are on cellular data."),
                    systemImage: "antenna.radiowaves.left.and.right"
                )
                .font(Tokens.caption)
                .foregroundStyle(Tokens.warning)
            }
            HStack {
                if isDownloading {
                    Button(localized("Stop")) { chosen.forEach(library.cancelDownload) }
                }
                Spacer()
                if isReady {
                    Button(localized("Continue")) {
                        settings.hasCompletedSetup = true
                        finish()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(localized("Download \(missing.formattedBytes)")) {
                        if network.isExpensive { confirmingCellular = true } else { download() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloading || !network.isConnected)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .tint(Tokens.accent)
    }

    private func download() {
        started = true
        Task { await library.downloadAll(chosen) }
    }

    private func updateMissing() async {
        missing = await library.missingBytes(of: chosen)
    }
}

/// A square check box on both platforms, matching the required model's mark.
struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Tokens.accent : Tokens.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? localized("On") : localized("Off"))
    }
}
