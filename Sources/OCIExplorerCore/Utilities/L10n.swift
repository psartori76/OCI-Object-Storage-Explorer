import Foundation

public enum L10n {
    public static let table = "Localizable"
    public static let defaultLocalization = "pt-BR"

    public static func string(_ key: String, locale: Locale = .autoupdatingCurrent) -> String {
        bundle(for: locale).localizedString(forKey: key, value: nil, table: table)
    }

    public static func string(_ key: String, locale: Locale = .autoupdatingCurrent, _ arguments: CVarArg...) -> String {
        let format = string(key, locale: locale)
        guard !arguments.isEmpty else { return format }
        return withVaList(arguments) { pointer in
            NSString(format: format, locale: locale, arguments: pointer) as String
        }
    }

    public static func plural(_ key: String, count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let format = string(key, locale: locale)
        return String(format: format, locale: locale, count)
    }

    public static func bundle(for locale: Locale = .autoupdatingCurrent) -> Bundle {
        for localization in preferredLocalizations(for: locale) {
            if let path = Bundle.module.path(forResource: localization, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return Bundle.module
    }

    public static func preferredLocalizations(for locale: Locale = .autoupdatingCurrent) -> [String] {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let languageCode = locale.language.languageCode?.identifier
        let regionCode = locale.region?.identifier

        var preferences: [String] = []
        if let languageCode, let regionCode {
            preferences.append("\(languageCode)-\(regionCode)")
        }
        if !identifier.isEmpty {
            preferences.append(identifier)
        }
        if let languageCode {
            preferences.append(languageCode)
        }
        preferences.append(defaultLocalization)

        let resolved = Bundle.preferredLocalizations(from: Bundle.module.localizations, forPreferences: preferences)
        return resolved + [defaultLocalization, "pt", "en", "es"]
    }
}
