internal protocol EnvironmentSetupProtocol {
    var valueNotFound: String { get }
    func value(for key: String) -> String?
    func deviceModel() -> String
    func deviceOsVersion() -> String
    func sdkName() -> String
    func sdkVersion() -> String
}

internal class Environment {
    let bundle: EnvironmentSetupProtocol
    private var baseUrl: URL? {
        guard let endpointUrlString = bundle.value(for: "RRCConfigAPIEndpoint") else {
            print("Ensure RRCConfigAPIEndpoint value in plist is valid")
            return nil
        }
        return URL(string: "\(endpointUrlString)")
    }
    var configUrl: URL? {
        guard let appId = bundle.value(for: "RASApplicationIdentifier") else {
            print("Ensure RASApplicationIdentifier value in plist is valid")
            return nil
        }
        return baseUrl?.appendingPathComponent("/app/\(appId)/config")
    }
    var subscriptionKey: String {
        return bundle.value(for: "RASProjectSubscriptionKey") ?? bundle.valueNotFound
    }
    var appId: String {
        return bundle.value(for: "CFBundleIdentifier" as String) ?? bundle.valueNotFound
    }
    var appName: String {
        return bundle.value(for: "CFBundleDisplayName" as String) ?? bundle.valueNotFound
    }
    var appVersion: String {
        return bundle.value(for: "CFBundleShortVersionString" as String) ?? bundle.valueNotFound
    }
    var deviceModel: String {
        return bundle.deviceModel()
    }
    var deviceOsVersion: String {
        return bundle.deviceOsVersion()
    }
    var sdkName: String {
        return bundle.sdkName()
    }
    var sdkVersion: String {
        return bundle.sdkVersion()
    }

    init(bundle: EnvironmentSetupProtocol = Bundle.main) {
        self.bundle = bundle
    }

    func keyUrl(with keyId: String) -> URL? {
        return baseUrl?.appendingPathComponent("/keys/\(keyId)")
    }
}
