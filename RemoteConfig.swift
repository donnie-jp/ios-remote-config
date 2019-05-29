struct ConfigModel: Decodable {
    let config: [String:String]
    
    enum CodingKeys: String, CodingKey {
        case config = "body"
    }
}

struct ConfigAPIError: Decodable {
    let code: Int
    let message: String
}

protocol APIClient {
    func send<T>(request: URLRequest, decodeAs: T.Type, completionHandler: @escaping (Result<Any, Error>) -> Void) where T : Decodable
}

public class ConfigFetcher {
    let apiClient: APIClient
    
    init(client: APIClient) {
        apiClient = client
    }
    
    func fetch() -> Void {

        apiClient.send(request: request, decodeAs: ConfigModel.self) { (result) in
            switch result {
            case .success(let config):
                print("Result config: ", config)
            case .failure(let error):
                print("Error: ", error)
            }
        }
    }
}

extension NSError {
    class func serverError(code: Int, message: String) -> NSError {
        return NSError(domain: "Remote Config Server", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

public class APIClientReal : APIClient {
    func send<T>(request: URLRequest, decodeAs: T.Type, completionHandler: @escaping (Result<Any, Error>) -> Void) where T : Decodable {
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                return print("No data received. Error: ", error ?? "no error")
            }
            let decoder = JSONDecoder()
            do {
                let config = try decoder.decode(decodeAs, from: data)
                completionHandler(.success(config))
            } catch let parseError {
                do {
                    let errorModel = try decoder.decode(ConfigAPIError.self, from: data)
                    completionHandler(.failure(NSError.serverError(code: errorModel.code, message: errorModel.message)))
                } catch {
                    completionHandler(.failure(parseError))
                }
            }
        }
        task.resume()
    }
}

public class RemoteConfig {

    public convenience init(foo: String) {
        self.init()
    }

    public func foo() {
    }
}
