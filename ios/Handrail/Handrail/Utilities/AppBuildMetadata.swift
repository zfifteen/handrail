import Foundation

struct AppBuildMetadata {
    let version: String
    let lastUpdated: String

    static var current: AppBuildMetadata {
        AppBuildMetadata(bundle: .main)
    }

    init(version: String, lastUpdated: String) {
        self.version = version
        self.lastUpdated = lastUpdated
    }

    init(bundle: Bundle) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        lastUpdated = bundle.object(forInfoDictionaryKey: "HandrailLastUpdated") as? String ?? ""
    }

    var versionText: String {
        "Version \(version)"
    }

    var lastUpdatedText: String {
        "Last updated \(lastUpdated)"
    }
}
