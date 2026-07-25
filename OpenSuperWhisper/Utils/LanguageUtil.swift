import Foundation
class LanguageUtil {

    static let availableLanguages = [
        "auto", "en", "zh", "de", "es", "ru", "ko", "fr", "ja", "pt", "tr", "pl", "ca", "nl", "ar",
        "he", "sv", "it", "id", "hi", "fi",
    ]

    static let parakeetV2Languages = ["en"]

    static let parakeetV3Languages = [
        "en", "de", "es", "ru", "fr", "pt", "pl", "nl", "sv", "it", "fi",
        "bg", "hr", "cs", "da", "el", "et", "hu", "lv", "lt", "mt", "ro", "sk", "sl", "uk",
    ]

    static let languageNames = [
        "auto": "Rilevamento automatico",
        "en": "Inglese",
        "zh": "Cinese",
        "de": "Tedesco",
        "es": "Spagnolo",
        "ru": "Russo",
        "ko": "Coreano",
        "fr": "Francese",
        "ja": "Giapponese",
        "pt": "Portoghese",
        "tr": "Turco",
        "pl": "Polacco",
        "ca": "Catalano",
        "nl": "Olandese",
        "ar": "Arabo",
        "he": "Ebraico",
        "sv": "Svedese",
        "it": "Italiano",
        "id": "Indonesiano",
        "hi": "Hindi",
        "fi": "Finlandese",
        "bg": "Bulgaro",
        "hr": "Croato",
        "cs": "Ceco",
        "da": "Danese",
        "el": "Greco",
        "et": "Estone",
        "hu": "Ungherese",
        "lv": "Lettone",
        "lt": "Lituano",
        "mt": "Maltese",
        "ro": "Rumeno",
        "sk": "Slovacco",
        "sl": "Sloveno",
        "uk": "Ucraino",
    ]

    static func supportedLanguages(engine: String, fluidAudioModelVersion: String) -> [String] {
        guard engine == "fluidaudio" else { return availableLanguages }
        return fluidAudioModelVersion == "v2" ? parakeetV2Languages : parakeetV3Languages
    }

    static func fallbackLanguage(engine: String) -> String {
        engine == "fluidaudio" ? "en" : "auto"
    }

    static func getSystemLanguage() -> String {
        if let preferredLanguage = Locale.preferredLanguages.first {
            let preferredLanguage = preferredLanguage.prefix(2).lowercased()
            return availableLanguages.contains(preferredLanguage) ? preferredLanguage : "en"
        } else {
            return "eng"
        }
    }
}
