import Foundation

class OpenAIService {
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }
    
    private var model: String {
        UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-4o"
    }
    
    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "systemPrompt") ?? """
        You are an AI text corrector. Fix any typos, grammatical errors, or awkward phrasing in the provided text. Maintain the original meaning and style.
        
        Return ONLY the corrected text without explanations or additional commentary.
        """
    }
    
    func correctText(_ text: String) async throws -> String? {
        print("OpenAI Service: Starting text correction")
        print("Text length: \(text.count) characters")
        
        guard !apiKey.isEmpty else {
            print("OpenAI Service Error: No API key set")
            throw OpenAIError.noApiKey
        }
        
        print("OpenAI Service: Using model: \(model)")
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            print("OpenAI Service: Sending request to OpenAI API")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("OpenAI Service Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("OpenAI Service: Received response with status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("OpenAI Service Error: Unauthorized - Invalid API key")
                throw OpenAIError.unauthorized
            } else if httpResponse.statusCode == 429 {
                print("OpenAI Service Error: Rate limit exceeded")
                throw OpenAIError.rateLimitExceeded
            } else if httpResponse.statusCode != 200 {
                print("OpenAI Service Error: API error with status code \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(OpenAIResponse.self, from: data)
                
                guard let content = result.choices.first?.message.content else {
                    print("OpenAI Service Error: No content in response")
                    throw OpenAIError.noResponseContent
                }
                
                print("OpenAI Service: Successfully received corrected text")
                return content
            } catch {
                print("OpenAI Service Error: JSON decoding error - \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                throw OpenAIError.invalidResponse
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            print("OpenAI Service Error: Network error - \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case noApiKey
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
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .unauthorized:
            return "Invalid API key. Please check your API key in Preferences."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .apiError(let statusCode):
            return "OpenAI API error: \(statusCode)"
        case .noResponseContent:
            return "No content in response from OpenAI."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct OpenAIResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Decodable {
        let role: String
        let content: String
    }
} 