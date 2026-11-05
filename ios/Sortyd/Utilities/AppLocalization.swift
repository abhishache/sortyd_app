import Foundation

enum AppLocalization {
    static func string(_ key: String, languageCode: String, bundle: Bundle = .main) -> String {
        // Locale controls formatting, but does not select a bundle's .lproj directory.
        guard let path = bundle.path(forResource: languageCode, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}
