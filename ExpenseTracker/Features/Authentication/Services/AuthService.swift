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
        print("🔗 将连接到API: \(APIConfig.baseURL)")
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
        
        return networkManager.request(
            endpoint: "/auth/register",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
        .map { response in
            print("📧 注册响应: success=\(response.success)")
            if response.success {
                print("✅ 注册成功,保存认证数据")
                self.saveAuthData(response.data)
            } else {
                print("❌ 注册失败: \(response.message ?? "未知错误")")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登录
    func login(email: String, password: String) -> AnyPublisher<Void, NetworkError> {
        print("📝 开始登录流程: \(email)")
        
        let request = LoginRequest(email: email, password: password)
        
        return networkManager.request(
            endpoint: "/auth/login",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
        .map { response in
            print("📧 登录响应: success=\(response.success)")
            if response.success {
                print("✅ 登录成功,保存认证数据")
                self.saveAuthData(response.data)
            } else {
                print("❌ 登录失败: \(response.message ?? "未知错误")")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登出
    func logout() {
        print("🚪 用户登出")
        UserDefaults.standard.removeObject(forKey: tokenKey)
        
        // ✅ 确保UI状态更新在主线程执行
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ 登出状态已在主线程更新")
        }
    }
    
    // MARK: - 获取当前用户信息
    func getCurrentUser() -> AnyPublisher<Void, NetworkError> {
        print("👤 获取当前用户信息")
        
        return networkManager.request(
            endpoint: "/auth/me",
            method: .GET,
            responseType: UserResponse.self
        )
        .map { response in
            if response.success {
                print("✅ 获取用户信息成功")
                // ✅ 确保UI状态更新在主线程执行
                DispatchQueue.main.async {
                    self.currentUser = response.data
                    self.isAuthenticated = true
                    print("✅ 用户信息状态已在主线程更新")
                }
            } else {
                print("❌ 获取用户信息失败")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    private func saveAuthData(_ authData: AuthData) {
        print("💾 开始保存认证数据")
        UserDefaults.standard.set(authData.token, forKey: tokenKey)
        
        // ✅ 确保UI状态更新在主线程执行
        DispatchQueue.main.async {
            self.currentUser = authData.user
            self.isAuthenticated = true
            print("✅ UI状态已在主线程更新")
        }
        
        print("💾 Token已保存")
        print("👤 用户已设置: \(authData.user.email)")
    }
    
    private func getStoredToken() -> String? {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        if let token = token {
            print("🔍 读取本地Token成功")
        } else {
            print("🔍 读取本地Token: 无Token")
        }
        return token
    }
    
    private func loadStoredAuth() {
        print("🔄 开始检查本地认证状态")
        
        if let token = getStoredToken() {
            print("✅ 发现本地Token,开始验证有效性")
            // 有token,尝试获取用户信息
            getCurrentUser()
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("❌ Token验证失败: \(error.localizedDescription)")
                            print("🧹 清除无效Token")
                            // token无效,清除本地数据
                            self?.logout()
                        }
                    },
                    receiveValue: { [weak self] _ in
                        print("✅ Token验证成功,用户已自动登录")
                    }
                )
                .store(in: &cancellables)
        } else {
            print("❌ 未发现本地Token,需要用户登录")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
}
