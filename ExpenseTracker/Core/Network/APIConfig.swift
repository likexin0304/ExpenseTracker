import Foundation

struct APIConfig {
    // ✅ 修正：根据API文档，基础URL应该包含/api前缀，但端点不需要重复
    static let baseURL = "http://127.0.0.1:3000"
    static let apiPrefix = "/api"
    static let timeout: TimeInterval = 30.0
    
    // ✅ 完整的API URL构建
    static func fullURL(for endpoint: String) -> String {
        return baseURL + apiPrefix + endpoint
    }
    
    // 调试信息
    static func debugInfo() {
        print("🌐 API配置:")
        print("📍 Base URL: \(baseURL)")
        print("🔗 API Prefix: \(apiPrefix)")
        print("⏱️ Timeout: \(timeout)秒")
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}
