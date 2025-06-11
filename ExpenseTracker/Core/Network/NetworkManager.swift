import Foundation
import Combine

/// 详细错误响应模型
struct DetailedErrorResponse: Codable {
    let success: Bool
    let message: String
    let error: ErrorDetails?
    let help: HelpInfo?
}

/// 错误详情模型
struct ErrorDetails: Codable {
    let type: String?
    let details: String?
    let suggestions: [String]?
    let receivedBody: String?
}

/// 帮助信息模型
struct HelpInfo: Codable {
    let correctFormat: String?
    let example: String?
    let documentation: String?
}

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let session = URLSession.shared
    
    private init() {
        print("🌐 NetworkManager初始化")
        APIConfig.debugInfo()
    }
    
    // MARK: - 主要请求方法
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Codable? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        
        // ✅ 构建完整URL，使用APIConfig.fullURL
        var urlComponents = URLComponents(string: APIConfig.fullURL(for: endpoint))
        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            print("❌ 无效URL: \(APIConfig.fullURL(for: endpoint))")
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = APIConfig.timeout
        
        // 设置默认headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加自定义headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加认证token
        if let token = getStoredToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 设置body
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
                print("📦 请求体已编码")
            } catch {
                print("❌ 请求体编码失败: \(error)")
                return Fail(error: NetworkError.decodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        print("🚀 发起网络请求: \(method.rawValue) \(url)")
        print("📋 请求头: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📦 请求体: \(bodyString)")
        }
        
        return session.dataTaskPublisher(for: request)
            .map { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 响应状态码: \(httpResponse.statusCode)")
                    print("📋 响应头: \(httpResponse.allHeaderFields)")
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 响应数据: \(responseString)")
                }
                return data
            }
            .tryMap { data -> T in
                // 首先尝试解析为统一API响应格式
                if let apiResponse = try? JSONDecoder().decode(APIResponse<T>.self, from: data) {
                    if apiResponse.success {
                        return apiResponse.data
                    } else {
                        // 处理后端返回的业务错误
                        throw NetworkError.serverError(apiResponse.message ?? "未知错误")
                    }
                }
                
                // 如果不是统一格式，尝试直接解析目标类型
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("❌ JSON解析失败: \(error)")
                    
                    // 尝试解析详细错误信息
                    if let errorResponse = try? JSONDecoder().decode(DetailedErrorResponse.self, from: data) {
                        var errorMessage = errorResponse.message
                        
                        // 如果有详细的建议信息，添加到错误消息中
                        if let suggestions = errorResponse.error?.suggestions {
                            errorMessage += "\n建议：\(suggestions.joined(separator: "；"))"
                        }
                        
                        throw NetworkError.serverError(errorMessage)
                    }
                    
                    throw NetworkError.decodingError
                }
            }
            .mapError { error in
                print("❌ 网络请求失败: \(error)")
                if let networkError = error as? NetworkError {
                    return networkError
                } else if error is DecodingError {
                    return NetworkError.decodingError
                } else {
                    return NetworkError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 便捷方法重载
    
    // 不带body的GET请求
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        return request(
            endpoint: endpoint,
            method: method,
            headers: headers,
            queryItems: queryItems,
            body: nil as String?,
            responseType: responseType
        )
    }
    
    // 带body的POST/PUT请求
    func request<T: Codable, B: Codable>(
        endpoint: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        body: B,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        return request(
            endpoint: endpoint,
            method: method,
            headers: headers,
            queryItems: nil,
            body: body,
            responseType: responseType
        )
    }
    
    // MARK: - Token管理
    private func getStoredToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
}
