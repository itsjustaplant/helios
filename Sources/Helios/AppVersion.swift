import Foundation

enum AppVersion {
    // VERSION is bundled by SwiftPM so the menu also works with `swift run`.
    static let current: String = {
        if let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return bundled
        }
        #if HELIOS_DISTRIBUTION
        preconditionFailure("The packaged app version is missing.")
        #else
        guard let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("The app version resource is missing.")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
        #endif
    }()
}
