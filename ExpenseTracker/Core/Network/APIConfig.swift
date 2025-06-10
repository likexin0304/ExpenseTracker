import Foundation

struct APIConfig {
    static let baseURL = "http://localhost:3000/api"
    static let timeout: TimeInterval = 30.0
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}
