import Foundation
import Combine

/**
 * 网络管理器
 * 处理所有网络请求
 */
class NetworkManager {
    // MARK: - 共享实例
    static let shared = NetworkManager()
    
    // MARK: - 私有属性
    private let session = URLSession.shared
    private let baseURL = URL(string: APIConfig.baseURL)!
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 公共方法
    
    /// 发送网络请求（支持Encodable类型的请求体）
    func request<T: Decodable, E: Encodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod = .GET,
        body: E? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, body: body, responseType: responseType)
    }
    
    /// 发送网络请求（支持Dictionary类型的请求体）
    func request<T: Decodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, jsonBody: body, responseType: responseType)
    }
    
    /// 发送网络请求（支持URL查询参数）
    func request<T: Decodable, E: Encodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod = .GET,
        queryItems: [URLQueryItem]? = nil,
        body: E? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, body: body, responseType: responseType)
    }
    
    /// 发送网络请求（支持Dictionary类型的请求体和URL查询参数）
    func request<T: Decodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod = .GET,
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, jsonBody: body, responseType: responseType)
    }
    
    /// 发送网络请求（支持路径参数）
    func request<T: Decodable, E: Encodable>(
        endpoint: APIConfig.Endpoint,
        pathComponent: String,
        method: HTTPMethod = .GET,
        body: E? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL(with: pathComponent)
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, body: body, responseType: responseType)
    }
    
    /// 发送网络请求（支持Dictionary类型的请求体和路径参数）
    func request<T: Decodable>(
        endpoint: APIConfig.Endpoint,
        pathComponent: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        let urlString = endpoint.fullURL(with: pathComponent)
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(url: url, method: method, jsonBody: body, responseType: responseType)
    }
    
    // MARK: - 私有方法
    
    /// 创建配置好的JSONDecoder
    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    /// 自动添加Authorization头（如果用户已登录）
    private func addAuthorizationHeader(to request: inout URLRequest) {
        // 直接从UserDefaults读取token，避免循环依赖
        let tokenKey = "supabase_access_token"
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 添加Authorization头部: Bearer \(token.prefix(20))...")
        } else {
            print("⚠️ 未获取到token，可能用户未登录")
        }
    }
    
    /// 执行网络请求（Encodable请求体）
    private func performRequest<T: Decodable, E: Encodable>(
        url: URL,
        method: HTTPMethod,
        body: E?,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // 自动添加Authorization头
        addAuthorizationHeader(to: &request)
        
        // 添加请求体
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: NetworkError.encodingError(error)).eraseToAnyPublisher()
            }
        }
        
        return executeRequest(request: request, responseType: responseType)
    }
    
    /// 执行网络请求（Dictionary请求体）
    private func performRequest<T: Decodable>(
        url: URL,
        method: HTTPMethod,
        jsonBody: [String: Any]?,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // 自动添加Authorization头
        addAuthorizationHeader(to: &request)
        
        // 添加请求体
        if let jsonBody = jsonBody {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
            } catch {
                return Fail(error: NetworkError.encodingError(error)).eraseToAnyPublisher()
            }
        }
        
        return executeRequest(request: request, responseType: responseType)
    }
    
    /// 执行请求并处理响应
    private func executeRequest<T: Decodable>(
        request: URLRequest,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // 打印请求和响应信息（调试用）
                self.logRequest(request, data: data, response: httpResponse)
                
                // ✅ 对于400错误，不直接抛出错误，而是返回数据让后续解码
                // 这样即使success=false，也能提取data.recordId等有用信息
                if httpResponse.statusCode == 400 {
                    // 检查数据是否为空
                    if data.isEmpty {
                        throw NetworkError.emptyData
                    }
                    // 返回数据，让后续的.decode()处理
                    // 调用者可以在tryMap中检查success字段来决定如何处理
                    return data
                }
                
                // 检查HTTP状态码
                if !(200...299).contains(httpResponse.statusCode) {
                    // 尝试解析错误响应
                    let errorMessage = self.parseErrorMessage(from: data)
                    
                    // 根据状态码返回特定错误
                    switch httpResponse.statusCode {
                    case 401:
                        throw NetworkError.unauthorized
                    case 403:
                        throw NetworkError.forbidden
                    case 404:
                        throw NetworkError.notFound(errorMessage ?? "资源不存在")
                    case 500...599:
                        throw NetworkError.serverError(errorMessage ?? "服务器错误")
                    default:
                        throw NetworkError.httpError(httpResponse.statusCode, errorMessage ?? "HTTP错误")
                    }
                }
                
                // 检查数据是否为空
                if data.isEmpty {
                    throw NetworkError.emptyData
                }
                
                return data
            }
            .decode(type: responseType, decoder: self.createJSONDecoder())
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if error is DecodingError {
                    return NetworkError.decodingError(error)
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// 解析错误消息
    private func parseErrorMessage(from data: Data) -> String? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 尝试不同的常见错误字段名
                if let message = json["message"] as? String {
                    return message
                } else if let error = json["error"] as? String {
                    return error
                } else if let errorMessage = json["errorMessage"] as? String {
                    return errorMessage
                } else if let errors = json["errors"] as? [[String: Any]], let firstError = errors.first, let msg = firstError["message"] as? String {
                    return msg
                }
            }
        } catch {
            print("解析错误消息失败: \(error)")
        }
        
        return nil
    }
    
    /// 打印请求和响应信息（调试用）
    private func logRequest(_ request: URLRequest, data: Data, response: HTTPURLResponse) {
        #if DEBUG
        print("🌐 REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("📋 HEADERS: \(headers)")
        }
        
        if let body = request.httpBody, !body.isEmpty {
            print("📦 REQUEST BODY: \(String(data: body, encoding: .utf8) ?? "无法解码")")
        }
        
        print("🔢 STATUS: \(response.statusCode)")
        
        if !data.isEmpty {
            print("📥 RESPONSE: \(String(data: data, encoding: .utf8) ?? "无法解码")")
        }
        #endif
    }
} 