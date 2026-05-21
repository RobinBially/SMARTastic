import Foundation

func loc(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}

func locf(_ key: String, _ args: CVarArg...) -> String {
    String(format: String(localized: String.LocalizationValue(key), bundle: .module), arguments: args)
}
