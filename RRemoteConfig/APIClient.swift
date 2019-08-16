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

    func send<T>(request: URLRequest, decodeAs: T.Type, completionHandler: @escaping (Result<Any, Error>, _ httpResponse: HTTPURLResponse?, _ httpData: Data?) -> Void) where T: Decodable {

        session.startTask(with: request) { (data, response, error) in
            let httpResponse = response as? HTTPURLResponse
            guard data != nil else {
                if let error = error {
                    return completionHandler(.failure(error), httpResponse, data)
                } else {
                    let serverError = NSError.serverError(code: httpResponse?.statusCode ?? 0, message: "Unspecified server error occurred")
                    return completionHandler(.failure(serverError), httpResponse, data)
                }
            }
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(decodeAs, from: data ?? Data())
                completionHandler(.success(result), httpResponse, data)
            } catch let parseError {
                do {
                    let errorModel = try decoder.decode(APIError.self, from: data ?? Data())
                    completionHandler(.failure(NSError.serverError(code: errorModel.code, message: errorModel.message)), httpResponse, data)
                } catch {
                    completionHandler(.failure(parseError), httpResponse, data)
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
