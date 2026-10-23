import Foundation
@preconcurrency import LLM

public enum QwenCleanerError: Error, Equatable, Sendable {
    case loadFailed
    case timedOut
    /// The transcript is longer than the cleanup handles in one pass.
    case tooLong
}

/// Cleans up with the Qwen model through LLM.swift (ADR 0006), as ghost-pepper calls it: the
/// resolved Qwen chat template, thinking suppressed, a low temperature, a fresh history per text.
@MainActor
public final class QwenCleaner: Cleaning {
    /// The model's context, prompt and answer together.
    nonisolated static let contextTokens: Int32 = 4096
    /// Transcripts longer than this are not cleaned up, so that the answer cannot be cut off by
    /// the end of the context (`docs/SPEC.md` §"Scope of the first version": short texts).
    public static let maximumCharacters = 4000

    private let llm: LLM
    private let timeout: Duration

    private init(llm: LLM, timeout: Duration) {
        self.llm = llm
        self.timeout = timeout
    }

    /// Loads the GGUF file. Loading takes a moment and runs off the main actor.
    public static func load(from file: URL, timeout: Duration = .seconds(20)) async throws
        -> QwenCleaner
    {
        let path = file.path(percentEncoded: false)
        let loaded = await Task.detached {
            Unchecked(
                LLM(
                    from: path, temp: 0.1, historyLimit: 2 * CleanupPrompt.examples.count,
                    maxTokenCount: contextTokens))
        }.value
        guard let llm = loaded.value else { throw QwenCleanerError.loadFailed }
        llm.update = { _ in }
        llm.postprocess = { _ in }
        llm.useResolvedTemplate(systemPrompt: CleanupPrompt.system)
        return QwenCleaner(llm: llm, timeout: timeout)
    }

    /// Runs one short generation, so that llama.cpp compiles its Metal shaders now rather than
    /// in the first dictation; that took over 10 s in the iOS Simulator
    /// (`plans/FIRST_VERSION.md` §"Status").
    public func warmUp() async {
        llm.history = []
        await llm.respond(to: CleanupPrompt.userMessage(for: "ok"), thinking: .suppressed)
    }

    public func clean(_ transcript: String) async throws -> String {
        guard transcript.count <= Self.maximumCharacters else { throw QwenCleanerError.tooLong }
        llm.history = CleanupPrompt.examples.flatMap { example -> [Chat] in
            [(.user, CleanupPrompt.userMessage(for: example.transcript)), (.bot, example.cleaned)]
        }
        var timedOut = false
        let watchdog = Task { @MainActor [llm, timeout] in
            try await Task.sleep(for: timeout)
            timedOut = true
            llm.stop()
        }
        await llm.respond(to: CleanupPrompt.userMessage(for: transcript), thinking: .suppressed)
        watchdog.cancel()
        if timedOut { throw QwenCleanerError.timedOut }
        return llm.output
    }
}

extension QwenCleaner {
    /// Releases llama.cpp's backend. Call it once, when the process ends, after every cleaner
    /// was released (`Engines.unloadAll()`); a model still loaded at exit makes llama.cpp abort.
    public static func shutDownBackend() {
        LLM.shutdownBackend()
    }
}

/// Carries a value the compiler cannot prove `Sendable` out of the task that created it, when
/// nothing else holds a reference to it.
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
