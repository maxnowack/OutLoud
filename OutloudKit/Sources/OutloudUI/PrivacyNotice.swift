import OutloudKit
import SwiftUI

/// How Outloud processes and what leaves the device (`docs/SPEC.md` §"Transparency and
/// privacy"; `docs/DESIGN.md` §"PrivacyNotice").
public struct PrivacyNotice: View {
    let period: RetentionPeriod

    public init(period: RetentionPeriod) {
        self.period = period
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            point(
                "cpu", localized("On this device"),
                localized(
                    "Transcription and cleanup run on this device. Neither your voice nor your text is sent anywhere."
                ))
            point(
                "arrow.down.circle", localized("Model downloads"),
                localized(
                    "The only data transfer is downloading the models from Hugging Face, once, when you choose them."
                ))
            point(
                "clock", localized("Kept results"),
                period == .nothing
                    ? localized("Outloud keeps no results and no recordings.")
                    : localized(
                        "Results and their recordings are kept on this device for \(period.title), then deleted."
                    ))
        }
    }

    private func point(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(Tokens.accent)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(title).font(Tokens.heading)
                Text(text)
                    .font(Tokens.detail)
                    .foregroundStyle(Tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The licences and attributions of what Outloud includes or downloads
/// (`docs/DESIGN.md` §"Acknowledgements").
public struct Acknowledgements: View {
    public init() {}

    static let entries: [(name: String, notice: String)] = [
        (ModelCatalog.parakeetV3.displayName, ModelCatalog.parakeetV3.attribution),
        (ModelCatalog.qwen08B.displayName, ModelCatalog.qwen08B.attribution),
        ("FluidAudio", "FluidInference, Apache License 2.0 (github.com/FluidInference/FluidAudio)"),
        (
            "LLM.swift",
            "MIT License (github.com/eastriverlee/LLM.swift, the fork github.com/obra/LLM.swift)"
        ),
        ("llama.cpp", "The ggml authors, MIT License (github.com/ggml-org/llama.cpp)"),
        (
            "ghost-pepper",
            "The cleanup prompt is adapted from ghost-pepper, MIT License as stated in its README (github.com/matthartman/ghost-pepper)"
        ),
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            ForEach(Self.entries, id: \.name) { entry in
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text(entry.name).font(Tokens.heading)
                    Text(entry.notice)
                        .font(Tokens.caption)
                        .foregroundStyle(Tokens.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
