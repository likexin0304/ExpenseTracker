import Foundation

enum NetworkError: Error, LocalizedError {
    case networkError(URLError)
    case invalidURL
    case noData
    case decodingError
    case encodingError
    case serverError(String)
    case unauthorized
    case unknown(Error)
    case ocrServiceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .ocrServiceUnavailable:
            return "OCR服务暂时不可用，请稍后再试或使用手动添加方式"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unknown error"
    }
    
    func contains(_ string: String) -> Bool {
        return localizedDescription.lowercased().contains(string.lowercased())
    }
} 