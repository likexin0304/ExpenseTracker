import Foundation

// 注册请求
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let confirmPassword: String
}

// 登录请求
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// 认证响应
struct AuthResponse: Codable {
    let user: User
    let token: String
}

// 用户响应
struct UserResponse: Codable {
    let user: User
}
