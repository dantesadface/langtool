import Foundation

/// The kind of transformation to apply to selected text.
enum TransformMode {
    case translate
    case grammar
}

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case badResponse(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key set. Open LangTool ▸ Preferences to add one."
        case .badResponse(let detail):
            return "Claude API error: \(detail)"
        case .emptyResult:
            return "Claude returned no text."
        }
    }
}

/// Thin client over the Anthropic Messages API.
struct ClaudeClient {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    /// Transforms `text` according to `mode` and returns the resulting string.
    func transform(_ text: String, mode: TransformMode) async throws -> String {
        guard let apiKey = Settings.shared.apiKey, !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        let system = systemPrompt(for: mode)
        let model = Settings.shared.model

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": system,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.badResponse("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "status \(http.statusCode)"
            throw ClaudeError.badResponse(detail)
        }

        return try parseText(from: data)
    }

    /// Extracts concatenated text blocks from a Messages API response.
    private func parseText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw ClaudeError.badResponse("Unexpected response shape")
        }
        let text = content
            .compactMap { block -> String? in
                guard (block["type"] as? String) == "text" else { return nil }
                return block["text"] as? String
            }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw ClaudeError.emptyResult }
        return text
    }

    private func systemPrompt(for mode: TransformMode) -> String {
        let settings = Settings.shared
        switch mode {
        case .translate:
            let source = settings.sourceLanguage
            let target = settings.targetLanguage
            let from = source.lowercased() == "auto-detect"
                ? "the source language (auto-detect it)"
                : source
            return """
            You are a translation engine. Translate the user's text from \(from) into \(target).
            Rules:
            - Output ONLY the translated text. No preamble, no quotes, no explanations, no notes.
            - Preserve the original meaning, tone, formatting, line breaks, and any code or URLs.
            - If the text is already in \(target), return it unchanged.
            """
        case .grammar:
            return """
            You are a grammar and spelling correction engine. Correct the user's text in its
            ORIGINAL language. Fix grammar, spelling, punctuation, and awkward phrasing while
            preserving the original meaning, tone, and formatting.
            Rules:
            - Output ONLY the corrected text. No preamble, no quotes, no explanations, no notes.
            - Do not translate. Keep the same language as the input.
            - Preserve line breaks, and any code or URLs.
            """
        }
    }
}
