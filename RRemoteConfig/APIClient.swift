protocol SessionProtocol {
    func startTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
}

extension URLSession: SessionProtocol {
    func startTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        dataTask(with: request) { (data, response, error) in
            completionHandler(data, response, error)
        }.resume()
    }
}

internal class APIClient {
    let session: SessionProtocol

    init(session: SessionProtocol = URLSession.shared) {
        self.session = session
    }

    func send<T>(request: URLRequest, decodeAs: T.Type, completionHandler: @escaping (Result<Any, Error>, _ httpResponse: HTTPURLResponse?) -> Void) where T: Decodable {

        session.startTask(with: request) { (data, response, error) in
            let httpResponse = response as? HTTPURLResponse
            guard let data = data else {
                if let error = error {
                    return completionHandler(.failure(error), httpResponse)
                } else {
                    let serverError = NSError.serverError(code: httpResponse?.statusCode ?? 0, message: "Unspecified server error occurred")
                    return completionHandler(.failure(serverError), httpResponse)
                }
            }
            let decoder = JSONDecoder()
            do {
                let config = try decoder.decode(decodeAs, from: data)
                completionHandler(.success(config), httpResponse)
            } catch let parseError {
                do {
                    let errorModel = try decoder.decode(APIError.self, from: data)
                    completionHandler(.failure(NSError.serverError(code: errorModel.code, message: errorModel.message)), httpResponse)
                } catch {
                    completionHandler(.failure(parseError), httpResponse)
                }
            }
        }
    }
}

struct APIError: Decodable, Equatable {
    let code: Int
    let message: String
}

fileprivate extension NSError {
    class func serverError(code: Int, message: String) -> NSError {
        return NSError(domain: "Remote Config Server", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
