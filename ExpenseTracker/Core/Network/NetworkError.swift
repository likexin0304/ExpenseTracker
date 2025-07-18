import Foundation

/**
 * 网络错误枚举
 * 定义所有可能的网络错误类型
 */
enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound(String)
    case serverError(String)
    case httpError(Int, String)
    case encodingError(Error)
    case decodingError(Error)
    case emptyData
    case ocrServiceUnavailable
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .unauthorized:
            return "未授权，请登录"
        case .forbidden:
            return "访问被禁止"
        case .notFound(let message):
            return "资源不存在: \(message)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .httpError(let code, let message):
            return "HTTP错误 \(code): \(message)"
        case .encodingError:
            return "编码错误"
        case .decodingError:
            return "解码错误"
        case .emptyData:
            return "返回数据为空"
        case .ocrServiceUnavailable:
            return "OCR服务暂时不可用"
        case .unknown:
            return "未知错误"
        }
    }
    
    // 实现Equatable协议
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.emptyData, .emptyData),
             (.ocrServiceUnavailable, .ocrServiceUnavailable):
            return true
        case (.notFound(let lhsMessage), .notFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.httpError(let lhsCode, let lhsMessage), .httpError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.encodingError(let lhsError), .encodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
