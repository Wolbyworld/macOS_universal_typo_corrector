import Foundation

/// Append-only TSV logger for evaluation datasets.
/// One line per entry with the following columns:
/// timestamp, prompt, completion, system_prompt, model, tokens_in, tokens_out, reasoning_effort
final class EvalLogger {
    static let shared = EvalLogger()

    private let ioQueue = DispatchQueue(label: "EvalLogger.IO")
    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        // ~/Library/Application Support/Luzia/Evals/evals_log.tsv
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Luzia", isDirectory: true)
            .appendingPathComponent("Evals", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("evals_log.tsv", isDirectory: false)

        // Write header if file doesn't exist
        if !fm.fileExists(atPath: fileURL.path) {
            let header = "timestamp\tprompt\tcompletion\tsystem_prompt\tmodel\ttokens_in\ttokens_out\treasoning_effort\n"
            try? header.data(using: .utf8)?.write(to: fileURL, options: .atomic)
        }
    }

    func log(timestamp: Date = Date(),
             prompt: String,
             completion: String,
             systemPrompt: String,
             model: String,
             tokensIn: Int,
             tokensOut: Int,
             reasoningEffort: String?) {
        let line = makeTSVLine(timestamp: timestamp,
                               prompt: prompt,
                               completion: completion,
                               systemPrompt: systemPrompt,
                               model: model,
                               tokensIn: tokensIn,
                               tokensOut: tokensOut,
                               reasoningEffort: reasoningEffort)
        ioQueue.async { [fileURL] in
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                do { try handle.seekToEnd() } catch { /* ignore */ }
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private func makeTSVLine(timestamp: Date,
                             prompt: String,
                             completion: String,
                             systemPrompt: String,
                             model: String,
                             tokensIn: Int,
                             tokensOut: Int,
                             reasoningEffort: String?) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ts = iso.string(from: timestamp)

        let cols: [String] = [
            ts,
            escapeTSV(prompt),
            escapeTSV(completion),
            escapeTSV(systemPrompt),
            escapeTSV(model),
            String(tokensIn),
            String(tokensOut),
            escapeTSV(reasoningEffort ?? "")
        ]
        return cols.joined(separator: "\t") + "\n"
    }

    private func escapeTSV(_ s: String) -> String {
        // Keep it one-line and spreadsheet-friendly
        return s
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}





