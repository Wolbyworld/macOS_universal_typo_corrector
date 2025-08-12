import Foundation

/// Append-only TSV error logger stored alongside eval logs, to avoid polluting eval dataset.
/// Columns: timestamp, stage, model, reasoning_effort, input_len, status_code, reason, details
final class ErrorLogger {
    static let shared = ErrorLogger()

    private let ioQueue = DispatchQueue(label: "ErrorLogger.IO")
    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Luzia", isDirectory: true)
            .appendingPathComponent("Evals", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("evals_errors.tsv", isDirectory: false)

        if !fm.fileExists(atPath: fileURL.path) {
            let header = "timestamp\tstage\tmodel\treasoning_effort\tinput_len\tstatus_code\treason\tdetails\n"
            try? header.data(using: .utf8)?.write(to: fileURL, options: .atomic)
        }
    }

    func log(stage: String,
             model: String,
             reasoningEffort: String?,
             inputLength: Int?,
             statusCode: Int?,
             reason: String?,
             details: String?) {
        let line = makeTSVLine(stage: stage,
                               model: model,
                               reasoningEffort: reasoningEffort,
                               inputLength: inputLength,
                               statusCode: statusCode,
                               reason: reason,
                               details: details)
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

    private func makeTSVLine(stage: String,
                             model: String,
                             reasoningEffort: String?,
                             inputLength: Int?,
                             statusCode: Int?,
                             reason: String?,
                             details: String?) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ts = iso.string(from: Date())

        let cols: [String] = [
            ts,
            escape(stage),
            escape(model),
            escape(reasoningEffort ?? ""),
            String(inputLength ?? 0),
            String(statusCode ?? 0),
            escape(reason ?? ""),
            escape(details ?? "")
        ]
        return cols.joined(separator: "\t") + "\n"
    }

    private func escape(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}


