import Foundation
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let networkManager = NetworkManager.shared
    private let tokenKey = "auth_token"
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        print("🚀 AuthService初始化")
        loadStoredAuth()
    }
    
    // MARK: - 注册
    func register(email: String, password: String, confirmPassword: String) -> AnyPublisher<Void, NetworkError> {
        print("📝 开始注册流程: \(email)")
        
        let request = RegisterRequest(
            email: email,
            password: password,
            confirmPassword: confirmPassword
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            print("❌ 注册请求编码失败")
            return Fail(error: NetworkError.decodingError)
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: "/auth/register",
            method: .POST,
            body: requestData,
            responseType: AuthResponse.self
        )
        .map { response in
            print("📧 注册响应: success=\(response.success), message=\(response.message)")
            if response.success, let authData = response.data {
                print("✅ 注册成功，保存认证数据")
                self.saveAuthData(authData)
            } else {
                print("❌ 注册失败: \(response.message)")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登录
    func login(email: String, password: String) -> AnyPublisher<Void, NetworkError> {
        print("📝 开始登录流程: \(email)")
        
        let request = LoginRequest(email: email, password: password)
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            print("❌ 登录请求编码失败")
            return Fail(error: NetworkError.decodingError)
                .eraseToAnyPublisher()
        }
        
        return networkManager.request(
            endpoint: "/auth/login",
            method: .POST,
            body: requestData,
            responseType: AuthResponse.self
        )
        .map { response in
            print("📧 登录响应: success=\(response.success), message=\(response.message)")
            if response.success, let authData = response.data {
                print("✅ 登录成功，保存认证数据")
                self.saveAuthData(authData)
            } else {
                print("❌ 登录失败: \(response.message)")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登出
    func logout() {
        print("🚪 用户登出")
        UserDefaults.standard.removeObject(forKey: tokenKey)
        currentUser = nil
        isAuthenticated = false
        print("🧹 本地认证数据已清除")
    }
    
    // MARK: - 获取当前用户
    func getCurrentUser() -> AnyPublisher<Void, NetworkError> {
        print("🔍 开始获取当前用户信息")
        
        guard let token = getStoredToken() else {
            print("❌ 未找到本地Token")
            return Fail(error: NetworkError.serverError("没有找到token"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        print("🔑 使用Token发起请求: \(token.prefix(20))...")
        
        return networkManager.request(
            endpoint: "/auth/me",
            method: .GET,
            headers: headers,
            responseType: UserResponse.self
        )
        .map { response in
            print("📧 获取用户响应: success=\(response.success)")
            if response.success, let userData = response.data {
                print("✅ 用户信息获取成功: \(userData.user.email)")
                self.currentUser = userData.user
                self.isAuthenticated = true
                print("🔐 认证状态已更新: \(self.isAuthenticated)")
            } else {
                print("❌ 获取用户信息失败")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    private func saveAuthData(_ authData: AuthResponse) {
        print("💾 开始保存认证数据")
        UserDefaults.standard.set(authData.token, forKey: tokenKey)
        currentUser = authData.user
        isAuthenticated = true
        
        print("💾 Token已保存: \(authData.token.prefix(20))...")
        print("👤 用户已设置: \(authData.user.email)")
        print("🔐 认证状态: \(isAuthenticated)")
        
        // 验证是否真的保存成功
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey) {
            print("✅ Token保存验证成功: \(savedToken.prefix(20))...")
        } else {
            print("❌ Token保存验证失败")
        }
    }
    
    private func getStoredToken() -> String? {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        if let token = token {
            print("🔍 读取本地Token成功: \(token.prefix(20))...")
        } else {
            print("🔍 读取本地Token: 无Token")
        }
        return token
    }
    
    private func loadStoredAuth() {
        print("🔄 开始检查本地认证状态")
        
        if let token = getStoredToken() {
            print("✅ 发现本地Token，开始验证有效性")
            // 有token，尝试获取用户信息
            getCurrentUser()
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("❌ Token验证失败: \(error.localizedDescription)")
                            print("🧹 清除无效Token")
                            // token无效，清除本地数据
                            self?.logout()
                        }
                    },
                    receiveValue: { [weak self] _ in
                        print("✅ Token验证成功，用户已自动登录")
                    }
                )
                .store(in: &cancellables)
        } else {
            print("❌ 未发现本地Token，需要用户登录")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
}
