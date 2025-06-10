import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let session = URLSession.shared
    
    private init() {
        print("🌐 NetworkManager初始化")
    }
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) -> AnyPublisher<APIResponse<T>, NetworkError> {
        
        let fullURL = APIConfig.baseURL + endpoint
        print("🌐 准备网络请求: \(method.rawValue) \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ 无效URL: \(fullURL)")
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = APIConfig.timeout
        
        // 设置默认headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        print("📋 默认请求头: Content-Type = application/json")
        
        // 添加自定义headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
            // 只打印Authorization的前缀，保护完整token
            if key == "Authorization" {
                let tokenPreview = value.count > 20 ? String(value.prefix(20)) + "..." : value
                print("📋 请求头: \(key) = \(tokenPreview)")
            } else {
                print("📋 请求头: \(key) = \(value)")
            }
        }
        
        // 设置body
        if let body = body {
            request.httpBody = body
            print("📦 请求体大小: \(body.count) bytes")
        }
        
        print("🚀 发起网络请求...")
        
        return session.dataTaskPublisher(for: request)
            .map { data, response -> Data in
                // 打印响应状态
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 响应状态码: \(httpResponse.statusCode)")
                    
                    // 打印响应头（调试用）
                    if httpResponse.statusCode >= 400 {
                        print("📋 响应头: \(httpResponse.allHeaderFields)")
                    }
                } else {
                    print("📡 非HTTP响应")
                }
                
                print("📦 响应数据大小: \(data.count) bytes")
                
                // 打印响应内容（用于调试）
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 完整响应: \(responseString)")
                }
                
                return data
            }
            .tryMap { data -> APIResponse<T> in
                // 使用智能JSON解析
                return try self.parseAPIResponse(data: data, responseType: T.self)
            }
            .mapError { error -> NetworkError in
                print("❌ 网络请求失败: \(error)")
                
                if let networkError = error as? NetworkError {
                    return networkError
                } else if let decodingError = error as? DecodingError {
                    print("❌ JSON解析错误详情: \(decodingError)")
                    
                    // 详细的解析错误信息
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("❌ 缺少字段: \(key.stringValue)")
                        print("❌ 上下文: \(context.debugDescription)")
                        print("❌ 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("❌ 类型不匹配: 期望\(type)")
                        print("❌ 上下文: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("❌ 值不存在: 期望\(type)")
                        print("❌ 上下文: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("❌ 数据损坏: \(context.debugDescription)")
                    @unknown default:
                        print("❌ 未知解析错误")
                    }
                    
                    return NetworkError.decodingError
                } else if let urlError = error as? URLError {
                    print("❌ URL错误: \(urlError.localizedDescription)")
                    return NetworkError.networkError(urlError)
                } else {
                    print("❌ 其他网络错误: \(error)")
                    return NetworkError.networkError(error)
                }
            }
            .handleEvents(
                receiveSubscription: { _ in
                    print("🔄 网络请求已开始...")
                },
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ 网络请求成功完成")
                    case .failure(let error):
                        print("❌ 网络请求失败: \(error.localizedDescription)")
                    }
                },
                receiveCancel: {
                    print("🚫 网络请求被取消")
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    
    /**
     * 智能解析API响应
     * 能够处理有message和无message的不同响应格式
     */
    private func parseAPIResponse<T: Codable>(data: Data, responseType: T.Type) throws -> APIResponse<T> {
        let decoder = JSONDecoder()
        
        // 首先尝试标准的APIResponse格式（带message字段）
        if let standardResponse = try? decoder.decode(APIResponse<T>.self, from: data) {
            print("✅ 使用标准APIResponse格式解析成功")
            return standardResponse
        }
        
        print("⚠️ 标准格式解析失败，尝试智能解析...")
        
        // 如果标准格式失败，尝试手动解析JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let jsonDict = json else {
                print("❌ 无法解析为JSON字典")
                throw NetworkError.decodingError
            }
            
            print("📋 JSON字典keys: \(jsonDict.keys.sorted())")
            
            // 提取基础字段
            let success = jsonDict["success"] as? Bool ?? false
            let message = jsonDict["message"] as? String // 可选字段
            
            print("📊 解析结果: success=\(success), message=\(message ?? "无")")
            
            // 尝试解析data字段
            var responseData: T? = nil
            if let dataJson = jsonDict["data"] {
                print("📦 找到data字段，尝试解析...")
                let dataJsonData = try JSONSerialization.data(withJSONObject: dataJson, options: [])
                responseData = try decoder.decode(T.self, from: dataJsonData)
                print("✅ data字段解析成功")
            } else {
                print("⚠️ 未找到data字段")
            }
            
            let response = APIResponse<T>(success: success, message: message, data: responseData)
            print("✅ 智能解析成功")
            return response
            
        } catch let jsonError {
            print("❌ 智能解析失败: \(jsonError)")
            throw NetworkError.decodingError
        }
    }
}

// MARK: - NetworkManager扩展方法
extension NetworkManager {
    /**
     * 用于调试的方法：打印请求详情
     */
    private func debugRequest(_ request: URLRequest) {
        print("🔍 === 请求详情 ===")
        print("🔍 URL: \(request.url?.absoluteString ?? "无")")
        print("🔍 方法: \(request.httpMethod ?? "无")")
        print("🔍 请求头:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key == "Authorization" {
                let preview = value.count > 20 ? String(value.prefix(20)) + "..." : value
                print("🔍   \(key): \(preview)")
            } else {
                print("🔍   \(key): \(value)")
            }
        }
        // 🔧 修复：添加了缺失的 data 参数
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("🔍 请求体: \(bodyString)")
        }
        print("🔍 ==================")
    }
    
    /**
     * 用于调试的方法：打印响应详情
     */
    private func debugResponse(data: Data, response: URLResponse?) {
        print("🔍 === 响应详情 ===")
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 状态码: \(httpResponse.statusCode)")
            print("🔍 响应头: \(httpResponse.allHeaderFields)")
        }
        print("🔍 数据大小: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 响应内容: \(responseString)")
        }
        print("🔍 ==================")
    }
}
