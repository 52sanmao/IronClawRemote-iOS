import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(String)
    case decoding
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "接口地址无效"
        case .unauthorized: return "认证失败，请检查令牌是否正确"
        case .server(let message): return message
        case .decoding: return "数据解析失败"
        case .transport(let error): return error.localizedDescription
        }
    }
}

struct APIConfig {
    var baseURL: URL
    var token: String
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    var config: APIConfig?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(baseURL: URL, token: String) {
        config = APIConfig(baseURL: baseURL, token: token)
    }

    func request<T: Decodable>(path: String, method: String = "GET", queryItems: [URLQueryItem] = [], body: Data? = nil) async throws -> T {
        let data = try await rawRequest(path: path, method: method, queryItems: queryItems, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func rawRequest(path: String, method: String = "GET", queryItems: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        guard let config else { throw APIError.invalidURL }
        guard var components = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.server("无效响应")
            }
            switch http.statusCode {
            case 200 ... 299:
                return data
            case 401:
                throw APIError.unauthorized
            default:
                let message = String(data: data, encoding: .utf8) ?? "请求失败"
                throw APIError.server(message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }
}
