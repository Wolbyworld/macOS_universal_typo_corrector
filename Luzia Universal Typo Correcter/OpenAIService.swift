import Foundation

class OpenAIService {
    private var apiKey: String { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
    private var model: String { UserDefaults.standard.string(forKey: "selectedModel") ?? "openai/gpt-oss-20b" }
    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "systemPrompt") ?? """
        You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.

        Return ONLY the corrected text without explanations or additional commentary.
        """
    }

    private var reasoningEffort: String { UserDefaults.standard.string(forKey: "reasoningEffort") ?? "minimum" }

    // Proxy mode configuration
    private var useProxy: Bool { UserDefaults.standard.bool(forKey: "useProxy") }
    private var proxyURL: String { UserDefaults.standard.string(forKey: "proxyURL") ?? "" }
    private var proxySecret: String {
        // Check for bundled configuration first (enterprise builds)
        if let bundled = Bundle.main.object(forInfoDictionaryKey: "LuziaProxySecretHash") as? String,
           !bundled.isEmpty,
           !bundled.starts(with: "$") {
            return deobfuscateSecret(bundled)
        }

        // Fall back to Keychain for user-entered secrets
        return KeychainHelper.shared.retrieve(forKey: "proxySecret") ?? ""
    }
    private var reasoningEffortAPI: String? {
        switch reasoningEffort.lowercased() {
        case "minimum", "low": return "low"
        case "medium": return "medium"
        case "high": return "high"
        default: return nil
        }
    }

    private func isReasoningSupported(for model: String) -> Bool {
        return model.hasPrefix("gpt-5")
    }

    // Helper to deobfuscate bundled secret
    private func deobfuscateSecret(_ obfuscated: String) -> String {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let data = Data(base64Encoded: obfuscated) else {
            return ""
        }

        let keyData = bundleID.data(using: .utf8) ?? Data()
        var result = Data()

        for (i, byte) in data.enumerated() {
            let keyByte = keyData[i % keyData.count]
            result.append(byte ^ keyByte)
        }

        return String(data: result, encoding: .utf8) ?? ""
    }

    func correctText(_ text: String) async throws -> String? {
        // Validate credentials based on mode
        if useProxy {
            guard !proxyURL.isEmpty, !proxySecret.isEmpty else {
                throw OpenAIError.noProxyConfig
            }
        } else {
            guard !apiKey.isEmpty else { throw OpenAIError.noApiKey }
        }

        func buildRequest(includeReasoning: Bool) throws -> URLRequest {
            // Select endpoint based on mode
            let endpoint = useProxy
                ? "\(proxyURL)/v1/responses"
                : "https://api.openai.com/v1/responses"

            guard let url = URL(string: endpoint) else {
                throw OpenAIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")

            // Set auth headers based on mode
            if useProxy {
                request.addValue(proxySecret, forHTTPHeaderField: "X-Luzia-Secret")
            } else {
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("responses=v1", forHTTPHeaderField: "OpenAI-Beta")
            }

            var body: [String: Any] = [
                "model": model,
                "instructions": systemPrompt,
                "input": text,
                "max_output_tokens": 4000,
                "text": [
                    "format": ["type": "text"]
                ]
            ]

            if includeReasoning, isReasoningSupported(for: model), let effort = reasoningEffortAPI {
                body["reasoning"] = ["effort": effort]
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
        }

        func tryOnce(includeReasoning: Bool) async throws -> (Data, HTTPURLResponse) {
            let request = try buildRequest(includeReasoning: includeReasoning)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
            if httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 400, let s = String(data: data, encoding: .utf8) {
                    print("400 error: \(s)")
                }
            }
            return (data, httpResponse)
        }

        // First attempt: only include reasoning if model actually supports it
        let shouldUseReasoning = isReasoningSupported(for: model) && reasoningEffortAPI != nil
        var (data, httpResponse) = try await tryOnce(includeReasoning: shouldUseReasoning)

        // If 400 and error indicates reasoning unsupported, retry once without reasoning
        if httpResponse.statusCode == 400, let s = String(data: data, encoding: .utf8), s.contains("reasoning.effort") {
            ErrorLogger.shared.log(stage: "responses_400",
                                   model: model,
                                   reasoningEffort: reasoningEffortAPI,
                                   inputLength: text.count,
                                   statusCode: 400,
                                   reason: "unsupported_reasoning",
                                   details: String(s.prefix(200)))
            (data, httpResponse) = try await tryOnce(includeReasoning: false)
        }

        // Handle non-200 statuses after potential retry
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 { throw OpenAIError.unauthorized }
            if httpResponse.statusCode == 429 { throw OpenAIError.rateLimitExceeded }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse success body
        do {
            let result = try JSONDecoder().decode(OpenAIResponsesResult.self, from: data)
            if let corrected = result.output_text ?? result.first_output_text {
                // Log success (first try)
                let usage = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let usageDict = usage?["usage"] as? [String: Any]
                let tokensIn = usageDict?["input_tokens"] as? Int ?? 0
                let tokensOut = usageDict?["output_tokens"] as? Int ?? 0
                let effectiveReasoning = isReasoningSupported(for: model) ? reasoningEffortAPI : nil
                EvalLogger.shared.log(prompt: text,
                                      completion: corrected,
                                      systemPrompt: systemPrompt,
                                      model: model,
                                      tokensIn: tokensIn,
                                      tokensOut: tokensOut,
                                      reasoningEffort: effectiveReasoning)
                return corrected
            }

            // No text returned: inspect for incomplete due to max_output_tokens. Retry once without reasoning if we included it.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = obj["status"] as? String,
               status == "incomplete",
               let incomplete = obj["incomplete_details"] as? [String: Any],
               let reason = incomplete["reason"] as? String,
               reason == "max_output_tokens" {
                ErrorLogger.shared.log(stage: "responses_incomplete",
                                       model: model,
                                       reasoningEffort: reasoningEffortAPI,
                                       inputLength: text.count,
                                       statusCode: 200,
                                       reason: "max_output_tokens",
                                       details: nil)
                print("200 incomplete due to max_output_tokens; retrying without reasoning once")
                let retry = try await tryOnce(includeReasoning: false)
                let retryData = retry.0
                let retryResp = retry.1
                guard retryResp.statusCode == 200 else {
                    ErrorLogger.shared.log(stage: "responses_retry_non200",
                                           model: model,
                                           reasoningEffort: nil,
                                           inputLength: text.count,
                                           statusCode: retryResp.statusCode,
                                           reason: "retry_failed",
                                           details: nil)
                    throw OpenAIError.apiError(statusCode: retryResp.statusCode)
                }
                let retryResult = try JSONDecoder().decode(OpenAIResponsesResult.self, from: retryData)
                if let corrected = retryResult.output_text ?? retryResult.first_output_text {
                    // Log success (retry path)
                    let usage = (try? JSONSerialization.jsonObject(with: retryData)) as? [String: Any]
                    let usageDict = usage?["usage"] as? [String: Any]
                    let tokensIn = usageDict?["input_tokens"] as? Int ?? 0
                    let tokensOut = usageDict?["output_tokens"] as? Int ?? 0
                    EvalLogger.shared.log(prompt: text,
                                          completion: corrected,
                                          systemPrompt: systemPrompt,
                                          model: model,
                                          tokensIn: tokensIn,
                                          tokensOut: tokensOut,
                                          reasoningEffort: nil)
                    return corrected
                }
                if let s = String(data: retryData, encoding: .utf8) { print("200 but no text after retry. Raw: \(s)") }
                throw OpenAIError.noResponseContent
            }

            if let s = String(data: data, encoding: .utf8) { print("200 but no text. Raw: \(s)") }
            throw OpenAIError.noResponseContent
        } catch {
            if let s = String(data: data, encoding: .utf8) { print("Decode error: \(error). Raw: \(s)") }
            throw OpenAIError.invalidResponse
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case noApiKey
    case noProxyConfig
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case apiError(statusCode: Int)
    case noResponseContent
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "OpenAI API key is not set. Please add it in Preferences."
        case .noProxyConfig:
            return "Proxy URL or secret is not configured. Please check Preferences."
        case .invalidURL:
            return "Invalid proxy URL. Please check Preferences."
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .unauthorized:
            return "Invalid API key or proxy secret. Please check your credentials in Preferences."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .apiError(let statusCode):
            return "API error: \(statusCode)"
        case .noResponseContent:
            return "No content in response from API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// Responses API decoding
struct OpenAIResponsesResult: Decodable {
    let output_text: String?
    let output: [OutputItem]?

    var first_output_text: String? {
        guard let items = output else { return nil }
        for item in items {
            guard item.type == "message", let parts = item.content else { continue }
            for c in parts {
                if c.type == "output_text" || c.type == "text" {
                    if let v = c.text?.value { return v }
                }
            }
        }
        return nil
    }

    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            struct TextValueOrObject: Decodable {
                struct TextObject: Decodable { let value: String }
                let value: String?
                init(from decoder: Decoder) throws {
                    let c = try decoder.singleValueContainer()
                    if let s = try? c.decode(String.self) { self.value = s }
                    else if let o = try? c.decode(TextObject.self) { self.value = o.value }
                    else { self.value = nil }
                }
            }
            let type: String
            let text: TextValueOrObject?
        }
        let id: String?
        let type: String
        let status: String?
        let role: String?
        let content: [ContentItem]?
    }
}