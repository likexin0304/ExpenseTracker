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

// 认证数据（登录/注册成功后返回的数据）
struct AuthData: Codable {
    let user: User
    let token: String
}

// 认证响应（登录/注册接口的响应）
typealias AuthResponse = APIResponse<AuthData>

// 用户响应（获取用户信息接口的响应）
typealias UserResponse = APIResponse<User>

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
