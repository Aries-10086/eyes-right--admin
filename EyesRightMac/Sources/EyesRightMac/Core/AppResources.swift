import Foundation

enum AppResources {
    static var bundle: Bundle {
        if let url = Bundle.main.url(
            forResource: "EyesRightMac_EyesRightMac",
            withExtension: "bundle"
        ),
           let bundle = Bundle(url: url) {
            return bundle
        }

        // CLI / swift run：使用 SPM 生成的 Bundle.module
        return Bundle.module
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
