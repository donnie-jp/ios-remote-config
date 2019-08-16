internal class ConfigCache {
    let fetcher: Fetcher
    let poller: Poller
    let cacheUrl: URL
    let keyStore: KeyStore
    let verifier: Verifier
    private var activeConfig: ConfigModel? = ConfigModel(config: [:])
    private var numberFormatter: NumberFormatter

    init(fetcher: Fetcher,
         poller: Poller,
         cacheUrl: URL = FileManager.getCacheDirectory().appendingPathComponent("rrc-config.plist"),
         initialCacheContents: [String: String]? = nil,
         keyStore: KeyStore = KeyStore(),
         verifier: Verifier = Verifier()) {
        self.fetcher = fetcher
        self.poller = poller
        self.cacheUrl = cacheUrl
        self.numberFormatter = NumberFormatter()
        self.keyStore = keyStore
        self.verifier = verifier

        if let initialCacheContents = initialCacheContents {
            self.activeConfig = ConfigModel(config: initialCacheContents)
        }
        DispatchQueue.global(qos: .utility).async {
            if let dictionary = NSDictionary.init(contentsOf: self.cacheUrl) as? [String: Any] {
                #if DEBUG
                print("Config read from cache plist \(cacheUrl): \(dictionary)")
                #endif

                guard let configString = dictionary["config"] as? String,
                    let configData = configString.data(using: .utf8),
                    let configDic = try? JSONSerialization.jsonObject(with: configData, options: []) as? [String: String] else {
                    print("Cache contents invalid")
                    return
                }
                var configModel = ConfigModel(config: configDic, keyId: dictionary["keyId"] as? String ?? "")
                configModel.signature = dictionary["signature"] as? String

                if self.verifyContents(model: configModel) {
                    print("Set active config to cached contents")
                    self.activeConfig = configModel
                } else {
                    print("Cached dictionary contents failed verification")
                }
            } else {
                print("No cache found")
            }
        }
    }

    func refreshFromRemote() {
        self.poller.start {
            self.fetcher.fetchConfig { (result) in
                guard let configModel = result else {
                    return print("Config could not be refreshed from remote")
                }
                self.verifyContents(model: configModel, resultHandler: { (verified) in
                    if verified {
                        let dictionary = [
                            "config": configModel.jsonString as Any,
                            "keyId": configModel.keyId as Any,
                            "signature": configModel.signature as Any
                        ]
                        self.write(dictionary)
                    } else {
                        print("Fetched dictionary contents failed verification")
                    }
                })
            }
        }
    }

    fileprivate func write(_ config: [String: Any]) {
        DispatchQueue.global(qos: .utility).async {
            NSDictionary(dictionary: config).write(to: self.cacheUrl, atomically: true)
            #if DEBUG
            let readFromPlist = NSDictionary(contentsOf: self.cacheUrl)
            print("Config written to url \(self.cacheUrl):\n\n \(String(describing: readFromPlist))")
            #endif
        }
    }
}

extension FileManager {
    class func getCacheDirectory() -> URL {
        let cachePaths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return cachePaths[0]
    }
}

// MARK: Payload signature verification
extension ConfigCache {
    // synchronous verification with local key store
    func verifyContents(model: ConfigModel) -> Bool {
        guard let key = keyStore.key(for: model.keyId),
            let signature = model.signature,
            let data = model.jsonString?.data(using: .utf8) else {
            return false
        }
        return self.verifier.verify(signatureBase64: signature,
                                    objectData: data,
                                    keyBase64: key)
    }

    // asynchronous verification - fetches key from backend if key is not
    // found in local key store
    func verifyContents(model: ConfigModel, resultHandler: @escaping (Bool) -> Void ) {
        if let data = model.jsonString?.data(using: .utf8), let key = keyStore.key(for: model.keyId) {
            let verified = self.verifier.verify(signatureBase64: model.signature ?? "",
                                                objectData: data,
                                                keyBase64: key)
            resultHandler(verified)
        } else {
            fetcher.fetchKey(with: model.keyId) { (keyModel) in
                guard
                    let data = model.jsonString?.data(using: .utf8),
                    let key = keyModel?.key,
                    keyModel?.id == model.keyId else {
                    return resultHandler(false)
                }
                self.keyStore.addKey(key: key, for: model.keyId)
                let verified = self.verifier.verify(signatureBase64: model.signature ?? "",
                                                    objectData: data,
                                                    keyBase64: key)
                resultHandler(verified)
            }
        }
    }
}

// MARK: Get config methods
extension ConfigCache {
    func getString(_ key: String, _ fallback: String) -> String {
        guard let config = activeConfig?.config else {
            return fallback
        }
        return config[key] ?? fallback
    }

    func getBoolean(_ key: String, _ fallback: Bool) -> Bool {
        guard let config = activeConfig?.config, let value = config[key] else {
            return fallback
        }
        return (value as NSString).boolValue
    }

    func getNumber(_ key: String, _ fallback: NSNumber) -> NSNumber {
        guard
            let config = activeConfig?.config,
            let value = config[key] else {
                return fallback
        }
        return numberFormatter.number(from: value) ?? fallback
    }

    func getConfig() -> [String: String] {
        return activeConfig?.config ?? [:]
    }
}
