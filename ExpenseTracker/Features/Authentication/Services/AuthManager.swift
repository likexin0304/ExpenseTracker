import Foundation
import Combine
import Supabase

/**
 * 认证管理器
 * 负责处理 Supabase 认证相关操作
 * 
 * 架构说明：
 * - 使用 Supabase Auth SDK 进行用户认证
 * - 获取 Supabase JWT token 用于后端 API 调用
 * - 与现有 AuthService 协同工作
 * 
 * 状态：框架完成，等待 Supabase 模块导入后启用 API 调用
 */

// 添加Sendable协议支持
@available(iOS 16.0, *)
class AuthManager: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: ExpenseTracker.User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    static let shared = AuthManager()
    
    private init() {
        print("🔐 AuthManager 初始化")
        // 验证 SupabaseManager 配置
        if SupabaseManager.shared.isReady() {
            print("✅ SupabaseManager 配置就绪")
            setupAuthStateListener()
            checkCurrentSession()
        } else {
            print("⚠️ SupabaseManager 配置未就绪")
        }
    }
    
    // MARK: - Public Methods
    
    /**
     * 用户注册
     * 使用 Supabase Auth 进行注册
     */
    func signUp(email: String, password: String, username: String) -> AnyPublisher<Void, Error> {
        print("📧 开始注册用户: \(email)")
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            Task {
                do {
                    let response = try await SupabaseManager.shared.client.auth.signUp(
                        email: email,
                        password: password,
                        data: ["username": AnyJSON.string(username)]
                    )
                    
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        let user = response.user
                        // 创建默认用户
                        let appUser = ExpenseTracker.User(
                            id: user.id.uuidString,
                            email: email,
                            username: username,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        self?.handleAuthSuccess(user: appUser)
                    }
                    
                    promise(.success(()))
                } catch {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                    }
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 用户登录
     * 使用 Supabase Auth 进行登录
     */
    func signIn(email: String, password: String) -> AnyPublisher<Void, Error> {
        print("🔑 开始登录用户: \(email)")
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            Task {
                do {
                    let response = try await SupabaseManager.shared.client.auth.signIn(
                        email: email,
                        password: password
                    )
                    
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        let user = response.user
                        // 创建用户对象
                        let appUser = ExpenseTracker.User(
                            id: user.id.uuidString,
                            email: email,
                            username: user.userMetadata["username"] as? String ?? "User",
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        self?.handleAuthSuccess(user: appUser)
                    }
                    
                    promise(.success(()))
                } catch {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                    }
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 用户登出
     */
    func signOut() -> AnyPublisher<Void, Error> {
        print("🚪 用户登出")
        isLoading = true
        
        return Future { promise in
            Task {
                do {
                    try await SupabaseManager.shared.client.auth.signOut()
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.handleAuthSignOut()
                    }
                    
                    promise(.success(()))
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                    }
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 简化令牌获取：统一从UserDefaults读取
    var accessToken: String? {
        UserDefaults.standard.string(forKey: "supabase_token")
    }
    
    /**
     * 刷新访问令牌
     */
    func refreshToken() -> AnyPublisher<Void, Error> {
        print("🔄 刷新访问令牌")
        
        return Future { promise in
            Task {
                do {
                    let newSession = try await SupabaseManager.shared.client.auth.refreshSession()
                    DispatchQueue.main.async { [weak self] in
                        self?.saveAccessToken(newSession.accessToken)
                    }
                    
                    promise(.success(()))
                } catch {
                    print("❌ 刷新令牌失败：\(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /**
     * 设置认证状态监听器
     */
    private func setupAuthStateListener() {
        Task {
            for await authStateChange in SupabaseManager.shared.client.auth.authStateChanges {
                let event = authStateChange.event
                let session = authStateChange.session
                
                DispatchQueue.main.async { [weak self] in
                    switch event {
                    case .signedIn:
                        self?.handleAuthSuccess(session: session)
                    case .signedOut:
                        self?.handleAuthSignOut()
                    case .tokenRefreshed:
                        if let session = session {
                            self?.saveAccessToken(session.accessToken)
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    /**
     * 检查当前会话
     */
    private func checkCurrentSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                
                DispatchQueue.main.async { [weak self] in
                    self?.handleAuthSuccess(session: session)
                }
            } catch {
                print("❌ 获取当前会话失败: \(error.localizedDescription)")
            }
        }
    }
    
    /**
     * 处理认证成功
     */
    private func handleAuthSuccess(session: Session?) {
        guard let session = session else { return }
        
        print("✅ 认证成功: \(session.user.email ?? "unknown")")
        
        // 保存令牌
        saveAccessToken(session.accessToken)
        
        // 创建应用用户
        let appUser = ExpenseTracker.User(
            id: session.user.id.uuidString,
            email: session.user.email ?? "unknown@example.com",
            username: session.user.userMetadata["username"] as? String ?? "User",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 更新用户信息
        handleAuthSuccess(user: appUser)
    }
    
    /**
     * 处理认证成功 (用户信息)
     */
    private func handleAuthSuccess(user: ExpenseTracker.User?) {
        guard let user = user else { return }
        
        print("👤 用户信息更新: \(user.email)")
        
        // 更新状态
        self.isAuthenticated = true
        self.currentUser = user
    }
    
    /**
     * 处理认证登出
     */
    private func handleAuthSignOut() {
        print("🚪 用户已登出")
        
        // 清除状态
        self.isAuthenticated = false
        self.currentUser = nil
        self.isLoading = false
        
        // 清除令牌
        UserDefaults.standard.removeObject(forKey: "supabase_token")
    }
    
    /**
     * 保存访问令牌
     */
    private func saveAccessToken(_ token: String) {
        print("💾 保存访问令牌")
        UserDefaults.standard.set(token, forKey: "supabase_token")
        print("🔑 保存的令牌: \(accessToken != nil ? "有" : "无")")
    }
    
    /**
     * 验证邮箱格式
     */
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    /**
     * 验证密码强度
     */
    func validatePassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    /**
     * 打印调试信息
     */
    func printDebugInfo() {
        print("🔍 AuthManager 调试信息:")
        print("📱 认证状态: \(isAuthenticated)")
        print("👤 当前用户: \(currentUser?.email ?? "无")")
        print("⏳ 加载状态: \(isLoading)")
        print("❌ 错误信息: \(errorMessage ?? "无")")
        print("🔑 保存的令牌: \(accessToken != nil ? "有" : "无")")
        
        // 打印 SupabaseManager 状态
        SupabaseManager.shared.printDebugInfo()
    }
} 