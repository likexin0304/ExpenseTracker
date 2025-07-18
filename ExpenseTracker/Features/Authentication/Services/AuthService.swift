import Foundation
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let networkManager = NetworkManager.shared
    private let tokenKey = "supabase_access_token"
    private let debugLogger = LoginDebugLogger.shared
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        print("🚀 AuthService初始化，tokenKey: \(tokenKey)")
        debugLogger.log("🚀 AuthService初始化，tokenKey: \(tokenKey)")
        print("🔗 将连接到API: \(APIConfig.baseURL)")
        debugLogger.log("🔗 将连接到API: \(APIConfig.baseURL)")
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
            endpoint: .authRegister,
            method: .POST,
            body: request,
            responseType: APIResponse<AuthData>.self
        )
        .tryMap { response in
            print("📦 收到注册响应: success=\(response.success)")
            
            guard response.success else {
                let errorMessage = response.message ?? "注册失败"
                print("❌ 注册失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            print("✅ 注册成功,保存认证数据")
            if let authData = response.data {
                self.saveAuthData(authData)
            }
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登录
    func login(email: String, password: String) -> AnyPublisher<Void, NetworkError> {
        print("📝 开始登录流程: \(email)")
        debugLogger.log("📝 开始登录流程: \(email)")
        
        let request = LoginRequest(email: email, password: password)
        debugLogger.log("📦 创建登录请求: \(request)")
        
        return networkManager.request(
            endpoint: .authLogin,
            method: .POST,
            body: request,
            responseType: APIResponse<AuthData>.self
        )
        .tryMap { response in
            print("📦 收到登录响应: success=\(response.success)")
            self.debugLogger.log("📦 收到登录响应: success=\(response.success), message=\(response.message ?? "无消息")")
            
            guard response.success else {
                let errorMessage = response.message ?? "登录失败"
                print("❌ 登录失败: \(errorMessage)")
                self.debugLogger.log("❌ 登录失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            print("✅ 登录成功,保存认证数据")
            self.debugLogger.log("✅ 登录成功,保存认证数据")
            
            if let authData = response.data {
                self.debugLogger.log("👤 用户数据: \(authData.user)")
                self.debugLogger.log("🔑 Token: \(authData.token.prefix(20))...")
                self.saveAuthData(authData)
            }
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                self.debugLogger.log("❌ 登录解码错误: \(error)")
                return NetworkError.decodingError(error)
            }
        }
        .handleEvents(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    self.debugLogger.log("✅ 登录流程完成")
                case .failure(let error):
                    self.debugLogger.log("❌ 登录流程失败: \(error)")
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登出
    func logout() {
        print("🚪 用户登出")
        clearAllData()
    }
    
    // MARK: - 删除账号
    func deleteAccount(confirmationText: String) -> AnyPublisher<Void, NetworkError> {
        print("🗑️ 开始删除账号流程")
        
        let request = DeleteAccountRequest(confirmationText: confirmationText)
        
        return networkManager.request(
            endpoint: .authDeleteAccount,
            method: .DELETE,
            body: request,
            responseType: APIResponse<DeleteAccountResponse>.self
        )
        .tryMap { response in
            print("📧 删除账号响应: success=\(response.success)")
            
            guard response.success else {
                let errorMessage = response.message ?? "删除账号失败"
                print("❌ 删除账号失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            print("✅ 账号删除成功，清除所有本地数据")
            self.clearAllData()
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 清除所有数据
    private func clearAllData() {
        print("🧹 清除所有本地数据")
        
        // 清除认证相关数据
        UserDefaults.standard.removeObject(forKey: tokenKey)
        
        // 清除其他可能的缓存数据
        UserDefaults.standard.removeObject(forKey: "cached_expenses")
        UserDefaults.standard.removeObject(forKey: "cached_budget")
        UserDefaults.standard.removeObject(forKey: "user_preferences")
        
        // ✅ 确保UI状态更新在主线程执行
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ 所有状态已在主线程清除")
        }
    }
    
    // MARK: - 获取当前用户信息
    func getCurrentUser() -> AnyPublisher<Void, NetworkError> {
        print("👤 获取当前用户信息")
        
        return networkManager.request(
            endpoint: .authMe,
            method: .GET,
            responseType: APIResponse<User>.self
        )
        .tryMap { response in
            print("✅ 获取用户信息响应: success=\(response.success)")
            
            guard response.success else {
                let errorMessage = response.message ?? "获取用户信息失败"
                print("❌ 获取用户信息失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            print("✅ 获取用户信息成功")
            // ✅ 确保UI状态更新在主线程执行
            DispatchQueue.main.async {
                if let user = response.data {
                    self.currentUser = user
                    self.isAuthenticated = true
                    print("✅ 用户信息状态已在主线程更新")
                }
            }
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    private func saveAuthData(_ authData: AuthData) {
        print("💾 开始保存认证数据，使用key: \(tokenKey)")
        debugLogger.log("💾 开始保存认证数据，使用key: \(tokenKey)")
        
        UserDefaults.standard.set(authData.token, forKey: tokenKey)
        debugLogger.log("💾 Token已保存到UserDefaults，key: \(tokenKey)")
        
        // ✅ 确保UI状态更新在主线程执行
        DispatchQueue.main.async {
            self.debugLogger.log("🧵 切换到主线程更新UI状态")
            
            let oldUser = self.currentUser
            let oldAuth = self.isAuthenticated
            
            self.currentUser = authData.user
            self.isAuthenticated = true
            
            self.debugLogger.log("👤 用户状态更新: \(oldUser?.email ?? "nil") -> \(authData.user.email)")
            self.debugLogger.log("🔐 认证状态更新: \(oldAuth) -> \(self.isAuthenticated)")
            
            print("✅ UI状态已在主线程更新")
            self.debugLogger.log("✅ UI状态已在主线程更新")
        }
        
        print("💾 Token已保存到key: \(tokenKey)")
        print("👤 用户已设置: \(authData.user.email)")
        debugLogger.log("💾 认证数据保存完成")
    }
    
    private func getStoredToken() -> String? {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        if token != nil {
            print("🔑 找到存储的Token: \(String(describing: token?.prefix(10)))...")
        } else {
            print("🔑 未找到存储的Token")
        }
        return token
    }
    
    private func loadStoredAuth() {
        print("🔄 尝试加载存储的认证数据")
        
        if let token = getStoredToken() {
            print("✅ 找到Token，设置已认证状态")
            isAuthenticated = true
            
            // 尝试获取用户信息
            _ = getCurrentUser()
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 加载用户信息失败: \(error)")
                        // 如果获取用户信息失败，清除认证状态
                        self.clearAllData()
                    }
                }, receiveValue: { _ in
                    print("✅ 用户信息已加载")
                })
                .store(in: &LoginDebugLogger.shared.cancellables)
        } else {
            print("⚠️ 未找到Token，用户未登录")
            isAuthenticated = false
        }
    }
}
