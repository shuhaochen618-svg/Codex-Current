import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        localizationBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }

    private static let localizationBundle: Bundle = {
        if Bundle.main.path(forResource: "Localizable", ofType: "strings") != nil {
            return .main
        }

        let sourceResources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        return Bundle(path: sourceResources.path) ?? .main
    }()
}
