import Foundation

enum AppResources {
    static let bundle: Bundle = {
        // Distributed apps must not depend on SwiftPM's absolute build-directory fallback.
        if let url = Bundle.main.resourceURL?.appendingPathComponent("SMARTastic_SMARTastic.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()
}
func loc(_ key: String) -> String { String(localized: String.LocalizationValue(key), bundle: AppResources.bundle) }
func locf(_ key: String, _ args: CVarArg...) -> String { String(format: loc(key), arguments: args) }
