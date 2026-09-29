import Foundation

/// Localized UI string in the app's current language. Keys live in scripts/strings.tsv.
func tr(_ key: String, _ args: CVarArg...) -> String {
    render(Bundle.main.localizedString(forKey: key, value: nil, table: nil), args, locale: .current)
}

/// Same, forced to a language. Anything other than fr falls back to en.
func tr(_ key: String, locale: Locale, _ args: CVarArg...) -> String {
    render(languageBundle(for: locale).localizedString(forKey: key, value: nil, table: nil), args, locale: locale)
}

private func languageBundle(for locale: Locale) -> Bundle {
    let code = locale.language.languageCode?.identifier == "fr" ? "fr" : "en"
    guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
        return .main
    }
    return bundle
}

private func render(_ template: String, _ args: [CVarArg], locale: Locale) -> String {
    args.isEmpty ? template : String(format: template, locale: locale, arguments: args)
}
