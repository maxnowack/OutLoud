import OutloudKit
import OutloudLipreading
import OutloudUI
import SwiftUI

/// The settings of lip reading (`plans/LIP_READING.md`, `docs/SPEC.md` §"Lip reading").
struct LipReadingSettings: View {
    @Bindable var app: AppModel
    @State private var cameraAllowed = CameraLipReading.cameraAllowed
    @State private var practising = false
    @State private var confirmingDelete = false

    private var coach: LipReadingCoach { app.lipCoach }
    /// Read from the library, which the model's row changes as it downloads.
    private var hasModel: Bool { app.library.state(of: ModelCatalog.lipReading).isInstalled }

    var body: some View {
        Form {
            Section {
                ModelRow(model: ModelCatalog.lipReading, library: app.library, network: app.network)
            } header: {
                Label("Experimental", systemImage: "flask")
                    .foregroundStyle(Tokens.warning)
            } footer: {
                Text(
                    "Lip reading is experimental: it still misreads many words, and reads you better the more it learns from your dictations. It needs its model on this Mac."
                )
            }

            Section {
                Picker("Read the lips", selection: Bindable(app.settings).lipReading) {
                    Text("Off").tag(LipReadingMode.off)
                    Text("When there is no sound").tag(LipReadingMode.whenSilent)
                    Text("Always, without sound").tag(LipReadingMode.silent)
                }
                Picker("Language", selection: Bindable(app.settings).lipReadingLanguage) {
                    Text("German").tag("de")
                    Text("English").tag("en")
                }
                if !cameraAllowed {
                    LabeledContent("Camera access") {
                        Button("Allow…") {
                            Task { cameraAllowed = await CameraLipReading.requestCameraAccess() }
                        }
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                    Text(
                        "While you hold the shortcut, the camera watches your mouth. Mouth the words without sound, and Outloud reads them from your lips. The camera is on only while you hold the shortcut."
                    )
                    Text(
                        "The language follows what you last dictated aloud. To mouth words in the other one, choose it here first."
                    )
                }
            }

            Section {
                Toggle(
                    "Learn from my dictations", isOn: Bindable(app.settings).learnsFromDictations)
                LabeledContent("Samples kept") {
                    Text(
                        "\(coach.samples), \(coach.silentSamples) of them silent – \(ByteCountFormatter.string(fromByteCount: coach.bytes, countStyle: .file))"
                    )
                }
                LearningProgress(
                    coach: coach, language: app.settings.lipReadingLanguage, hasModel: hasModel)
                HStack {
                    Button("Practise Silently…") { practising = true }
                        .disabled(!cameraAllowed)
                    Button("Learn Now") { Task { await coach.train() } }
                        .disabled(coach.training == .running || !hasModel)
                    Spacer()
                    Button("Delete Samples…", role: .destructive) { confirmingDelete = true }
                        .disabled(coach.samples == 0)
                }
                TrainingStatus(
                    training: coach.shownTraining(app.settings.lipReadingLanguage),
                    progress: coach.progress)
            } footer: {
                Text(
                    "While you dictate aloud, the camera watches too — also with lip reading off — and Outloud keeps a small picture of your mouth with the transcript. It learns from them on this Mac while nobody uses it and it is plugged in, and tells you once it reads you well enough. Silent practice teaches it how your lips move without sound."
                )
            }
        }
        .formStyle(.grouped)
        .task { await coach.refresh() }
        .onChange(of: app.settings.lipReadingLanguage) {
            app.lipReading.reload()
            Task { await coach.refresh() }
        }
        .sheet(isPresented: $practising) {
            SilentPractice(app: app) { practising = false }
        }
        .confirmationDialog("Delete all samples?", isPresented: $confirmingDelete) {
            Button("Delete All", role: .destructive) { Task { await coach.deleteSamples() } }
        } message: {
            Text(
                "The pictures of your mouth and what Outloud learned from them are deleted from this Mac."
            )
        }
    }
}

/// How well the lips are read now, against what is good enough to use them, and where the
/// learning stands (`plans/LIP_READING.md` §"Phase 6").
private struct LearningProgress: View {
    let coach: LipReadingCoach
    let language: String
    let hasModel: Bool

    var body: some View {
        LabeledContent("Accuracy") {
            if let accuracy = coach.accuracy {
                VStack(alignment: .trailing, spacing: Tokens.Spacing.xs) {
                    if accuracy > 1 - LipReadingCoach.goodEnough {
                        Text("\(percent(accuracy)) – good enough to use")
                    } else {
                        Text(
                            "\(percent(accuracy)) – good enough from \(percent(1 - LipReadingCoach.goodEnough))"
                        )
                    }
                    // A share of a handful of sentences moves by many points with one word.
                    if coach.judgedOn > 0 {
                        Text("Measured on \(coach.judgedOn) held-back sentences")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Not measured yet")
            }
        }
        LabeledContent("Last learned") {
            if let date = coach.learnedOn {
                Text(
                    "\(date.formatted(.relative(presentation: .named))), from \(coach.learnedFrom) samples"
                )
            } else {
                Text("Not yet")
            }
        }
        LabeledContent("Next learning") {
            if coach.shownTraining(language) == .running {
                Text("Now")
            } else if !hasModel {
                Text("When the model is installed")
            } else if coach.newSamples < LipReadingCoach.automaticAfter {
                Text("After \(LipReadingCoach.automaticAfter - coach.newSamples) more samples")
            } else {
                Text("When this Mac is idle and plugged in")
            }
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

extension LipReadingCoach {
    /// The training of `language`: an idle Mac may be learning the other one.
    fileprivate func shownTraining(_ language: String) -> Training {
        trainingLanguage == language ? training : .idle
    }
}

private struct TrainingStatus: View {
    let training: LipReadingCoach.Training
    let progress: LipTraining.Progress?

    var body: some View {
        switch training {
        case .idle:
            EmptyView()
        case .running:
            if let progress {
                ProgressView(value: progress.fraction) {
                    Text("Learning from your samples…")
                } currentValueLabel: {
                    Text(step(progress))
                }
            } else {
                HStack(spacing: Tokens.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Learning from your samples…")
                }
            }
        case .finished(let adopted, let before, let after):
            if adopted {
                Text(
                    "Learned: words misread fell from \(percent(before)) to \(percent(after)).")
            } else {
                Text(
                    "Nothing learned this time: \(percent(after)) words misread, \(percent(before)) before. The earlier state stays."
                )
                .foregroundStyle(.secondary)
            }
        case .tooFewSamples:
            Text("More samples are needed to learn from.").foregroundStyle(.secondary)
        case .failed:
            Text("Learning failed.").foregroundStyle(.secondary)
        }
    }

    private func step(_ progress: LipTraining.Progress) -> String {
        switch progress {
        case .preparing(let done, let of):
            String(localized: "Preparing sample \(done + 1) of \(of)")
        case .learning(let round, let of, _, _):
            String(localized: "Round \(round) of \(of)")
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// Shows sentences to mouth without sound; each becomes a silent sample with the sentence as
/// its text (`plans/LIP_READING.md` §"Phase 5").
private struct SilentPractice: View {
    let app: AppModel
    let close: () -> Void
    @State private var index = 0
    @State private var watching = false
    @State private var missedFace = false

    private var sentences: [String] {
        PracticeSentences.sentences(language: app.settings.lipReadingLanguage)
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.l) {
            Text("Sentence \(index + 1) of \(sentences.count)").foregroundStyle(.secondary)
            Text(sentences[index])
                .font(.title2)
                .multilineTextAlignment(.center)
                .frame(minHeight: 80)
            Text(
                watching
                    ? "Mouth the sentence without sound, looking at the camera. Then click Done."
                    : "Click Start, then mouth the sentence without sound."
            )
            .foregroundStyle(.secondary)
            if missedFace {
                Text("No face was seen. Sit in front of the camera and try again.")
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Close") {
                    Task {
                        if watching {
                            watching = false
                            await app.lipReading.cancelPractice()
                        }
                        close()
                    }
                }
                Spacer()
                Button("Skip") { index = (index + 1) % sentences.count }
                    .disabled(watching)
                if watching {
                    Button("Done") {
                        Task {
                            let kept = await app.lipReading.finishPractice(
                                sentence: sentences[index])
                            watching = false
                            missedFace = !kept
                            if kept { index = (index + 1) % sentences.count }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start") { watching = app.lipReading.startPractice() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(Tokens.Spacing.xl)
        .frame(width: 460)
        // The camera runs only between Start and Done (ADR 0034), however the sheet goes away.
        .onDisappear {
            if watching { Task { await app.lipReading.cancelPractice() } }
        }
    }
}
