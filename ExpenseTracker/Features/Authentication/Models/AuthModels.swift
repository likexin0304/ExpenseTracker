import Foundation

/**
 * 登录凭证模型
 */
struct LoginCredentials: Codable {
    let email: String
    let password: String
}

/**
 * 注册凭证模型
 */
struct RegisterCredentials: Codable {
    let email: String
    let password: String
    let username: String
}

/**
 * 认证响应模型
 */
struct AuthResponse: Codable {
    let user: User
    let token: String
}

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

// 认证数据（登录/注册成功后返回的数据）
struct AuthData: Codable {
    let user: User
    let token: String
}

// 用户响应（获取用户信息接口的响应）
typealias UserResponse = APIResponse<User>

// GET /api/auth/me 的响应数据结构
struct AuthMeData: Codable {
    let user: User
}

// GET /api/auth/me 的完整响应
typealias AuthMeResponse = APIResponse<AuthMeData>

// MARK: - 删除账号请求
struct DeleteAccountRequest: Codable {
    let confirmationText: String
}

// MARK: - 删除账号响应
struct DeleteAccountResponse: Codable {
    let success: Bool
    let message: String
    let data: DeleteAccountData?
}

struct DeleteAccountData: Codable {
    let deletedAt: String
    let message: String
}
