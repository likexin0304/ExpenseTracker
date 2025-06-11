import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case networkError(Error)
    case unauthorized
    case unknown(Error)  // ✅ 添加这个
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有数据返回"
        case .decodingError:
            return "数据解析失败"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "未授权访问"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}
