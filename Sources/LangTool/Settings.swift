import Foundation

/// User-configurable settings, persisted in UserDefaults (API key lives in Keychain).
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let model = "model"
        static let translateHotKey = "translateHotKey"
        static let grammarHotKey = "grammarHotKey"
        static let previewBeforeReplace = "previewBeforeReplace"
    }

    private init() {
        // Sensible defaults: Tagalog -> English, preview on, on first launch.
        defaults.register(defaults: [
            Keys.sourceLanguage: "Tagalog",
            Keys.targetLanguage: "English",
            Keys.model: "claude-haiku-4-5-20251001",
            Keys.previewBeforeReplace: true
        ])
    }

    /// Source language for translation. "Auto-detect" lets the model infer it.
    var sourceLanguage: String {
        get { defaults.string(forKey: Keys.sourceLanguage) ?? "Tagalog" }
        set { defaults.set(newValue, forKey: Keys.sourceLanguage) }
    }

    /// Target language for translation.
    var targetLanguage: String {
        get { defaults.string(forKey: Keys.targetLanguage) ?? "English" }
        set { defaults.set(newValue, forKey: Keys.targetLanguage) }
    }

    /// Claude model id used for both translation and grammar correction.
    var model: String {
        get { defaults.string(forKey: Keys.model) ?? "claude-haiku-4-5-20251001" }
        set { defaults.set(newValue, forKey: Keys.model) }
    }

    /// When true, show a preview window with the suggestion before replacing
    /// the selected text. When false, replace immediately.
    var previewBeforeReplace: Bool {
        get { defaults.bool(forKey: Keys.previewBeforeReplace) }
        set { defaults.set(newValue, forKey: Keys.previewBeforeReplace) }
    }

    var apiKey: String? {
        get { KeychainHelper.loadAPIKey() }
        set { KeychainHelper.saveAPIKey(newValue ?? "") }
    }

    var hasAPIKey: Bool {
        if let key = apiKey { return !key.isEmpty }
        return false
    }
}
