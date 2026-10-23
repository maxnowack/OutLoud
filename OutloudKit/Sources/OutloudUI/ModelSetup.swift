import OutloudKit
import SwiftUI

/// The first launch: choose or confirm the models and download them (`docs/SPEC.md` §"Models";
/// `docs/DESIGN.md` §"ModelSetup").
public struct ModelSetup: View {
    let library: ModelLibrary
    let settings: OutloudSettings
    let network: NetworkMonitor
    let finish: () -> Void
    @State private var cellularRequest: CellularRequest?
    @State private var showingPrivacy = false
    @State private var missing: Int64 = 0
    @State private var availability = CleanupAvailability.current

    public init(
        library: ModelLibrary, settings: OutloudSettings, network: NetworkMonitor,
        finish: @escaping () -> Void
    ) {
        self.library = library
        self.settings = settings
        self.network = network
        self.finish = finish
    }

    /// The models to download: the transcription model; the cleanup needs none (ADR 0019).
    private var chosen: [ModelDescriptor] { [settings.transcriptionModel] }

    private var isReady: Bool { chosen.allSatisfy { library.state(of: $0).isInstalled } }
    private var isDownloading: Bool { chosen.contains { library.state(of: $0).isDownloading } }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Text(localized("Welcome to Outloud")).font(Tokens.title)
                Text(
                    localized(
                        "Download the models once. After that, everything stays on this device.")
                )
                .font(Tokens.body)
                .foregroundStyle(Tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Tokens.Spacing.m) {
                transcriptionCard
                cleanupCard
            }

            Button(localized("What happens with my data?")) { showingPrivacy = true }
                .buttonStyle(.borderless)
                .tint(Tokens.accent)

            Spacer(minLength: 0)
            footer
        }
        .task { await updateMissing() }
        .trackingCleanupAvailability($availability)
        .onChange(of: library.states) { Task { await updateMissing() } }
        .sheet(isPresented: $showingPrivacy) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                PrivacyNotice(period: settings.retentionPeriod)
                Button(localized("Done")) { showingPrivacy = false }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(Tokens.Spacing.xl)
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            localized("Download over cellular data?"),
            isPresented: Binding(
                get: { cellularRequest != nil }, set: { if !$0 { cellularRequest = nil } }),
            titleVisibility: .visible, presenting: cellularRequest
        ) { request in
            Button(localized("Download \(request.bytes.formattedBytes)")) {
                start(request.models, overCellular: true)
            }
        } message: { _ in
            Text(
                localized(
                    "The models are large. Downloading them over cellular data may use up your data plan."
                ))
        }
    }

    private var transcriptionCard: some View {
        let model = settings.transcriptionModel
        return card {
            HStack(spacing: Tokens.Spacing.m) {
                Image(systemName: "checkmark.square.fill")
                    .font(.title2)
                    .foregroundStyle(Tokens.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(localized("Speech recognition")).font(Tokens.heading)
                    Text("\(model.displayName) · \(model.totalSize.formattedBytes)")
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            stateLine(for: model)
        }
    }

    private var cleanupCard: some View {
        card {
            Toggle(
                isOn: Binding(
                    get: { settings.cleanupEnabled && availability == .available },
                    set: { settings.cleanupEnabled = $0 })
            ) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(localized("Clean up text")).font(Tokens.heading)
                    Text(localized("Removes filler words, sets punctuation and paragraphs"))
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                }
            }
            .toggleStyle(CheckboxStyle())
            .disabled(availability != .available)
            CleanupAvailabilityNote(availability: availability)
        }
    }

    @ViewBuilder private func stateLine(for model: ModelDescriptor) -> some View {
        switch library.state(of: model) {
        case .installed:
            Label(localized("Already on this device"), systemImage: "checkmark.circle.fill")
                .font(Tokens.caption)
                .foregroundStyle(Tokens.success)
        case .downloading(let completed, let total):
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                ProgressView(value: Double(completed), total: Double(max(total, 1)))
                Text(localized("\(completed.formattedBytes) of \(total.formattedBytes)"))
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.textSecondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.failure)
                // Independent of the other model, which may still be downloading.
                Button(localized("Retry")) { request([model]) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!network.isConnected)
            }
        case .notInstalled:
            EmptyView()
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m, content: content)
            .padding(Tokens.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusLarge))
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: Tokens.Spacing.s) {
            if !network.isConnected && !isReady {
                Label(localized("There is no internet connection."), systemImage: "wifi.slash")
                    .font(Tokens.caption)
                    .foregroundStyle(Tokens.warning)
            }
            if isReady {
                Button {
                    settings.hasCompletedSetup = true
                    finish()
                } label: {
                    Text(localized("Continue")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else if isDownloading {
                Button {
                    chosen.forEach(library.cancelDownload)
                } label: {
                    Text(localized("Stop")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button {
                    request(chosen)
                } label: {
                    Text(localized("Download \(missing.formattedBytes)")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!network.isConnected)
                .keyboardShortcut(.defaultAction)
                Text(
                    network.isExpensive
                        ? localized("You are on cellular data.") : localized("Preferably on Wi-Fi.")
                )
                .font(Tokens.caption)
                .foregroundStyle(network.isExpensive ? Tokens.warning : Tokens.textSecondary)
            }
        }
        .tint(Tokens.accent)
    }

    /// Downloads the models, after asking when the connection is cellular.
    private func request(_ models: [ModelDescriptor]) {
        Task {
            let bytes = await library.missingBytes(of: models)
            if network.isExpensive {
                cellularRequest = CellularRequest(models: models, bytes: bytes)
            } else {
                start(models, overCellular: false)
            }
        }
    }

    private func start(_ models: [ModelDescriptor], overCellular: Bool) {
        Task { await library.downloadAll(models, overCellular: overCellular) }
    }

    private func updateMissing() async {
        missing = await library.missingBytes(of: chosen)
    }
}

/// Models waiting for the user to allow a download over cellular data.
private struct CellularRequest {
    let models: [ModelDescriptor]
    let bytes: Int64
}

/// A square check box on both platforms, matching the required model's mark.
struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Tokens.Spacing.m) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? Tokens.accent : Tokens.textSecondary)
                configuration.label
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? localized("On") : localized("Off"))
    }
}
