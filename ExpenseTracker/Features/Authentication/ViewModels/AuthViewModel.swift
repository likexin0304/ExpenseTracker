import Foundation
import SwiftUI
import Combine

/**
 * 认证视图模型
 * 处理登录、注册、账户管理等认证相关功能
 */
class AuthViewModel: ObservableObject {
    // MARK: - 共享实例
    static let shared = AuthViewModel()
    
    // MARK: - 服务依赖
    private let authService = AuthService.shared
    
    // MARK: - 发布属性
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - 登录相关状态
    @Published var email = ""
    @Published var password = ""
    @Published var isLoginMode = true
    
    // MARK: - 注册相关状态
    @Published var confirmPassword = ""
    @Published var username = ""
    
    // MARK: - 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
        checkAuthStatus()
    }
    
    // MARK: - 绑定设置
    private func setupBindings() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 认证操作
    func login() {
        isLoading = true
        errorMessage = ""
        
        authService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    if let networkError = error as? NetworkError {
                        self?.errorMessage = networkError.localizedDescription
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] _ in
                self?.clearForm()
            })
            .store(in: &cancellables)
    }
    
    func register() {
        guard validateRegistration() else { return }
        
        isLoading = true
        errorMessage = ""
        
        authService.register(email: email, password: password, confirmPassword: confirmPassword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    if let networkError = error as? NetworkError {
                        self?.errorMessage = networkError.localizedDescription
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] _ in
                self?.clearForm()
                self?.isLoginMode = true
            })
            .store(in: &cancellables)
    }
    
    func logout() {
        authService.logout()
        clearForm()
    }
    
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        authService.deleteAccount(confirmationText: "DELETE")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completionResult in
                switch completionResult {
                case .finished:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    func checkAuthStatus() {
        // 检查是否有保存的用户信息
        if authService.isAuthenticated {
            // 如果已经有用户信息，直接更新状态
            self.isAuthenticated = true
            self.currentUser = authService.currentUser
        } else {
            // 尝试获取最新的用户信息
            authService.getCurrentUser()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
    }
    
    // MARK: - 辅助方法
    private func validateRegistration() -> Bool {
        errorMessage = ""
        
        // 检查密码是否匹配
        if password != confirmPassword {
            errorMessage = "两次输入的密码不匹配"
            return false
        }
        
        // 检查密码长度
        if password.count < 6 {
            errorMessage = "密码必须至少包含6个字符"
            return false
        }
        
        // 检查用户名
        if username.isEmpty {
            errorMessage = "请输入用户名"
            return false
        }
        
        return true
    }
    
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        username = ""
        errorMessage = ""
    }
    
    func switchMode() {
        isLoginMode.toggle()
        clearForm()
    }
}
