import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听认证状态变化
        authService.$isAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - 注册
    func register() {
        guard validateRegistrationInput() else { return }
        
        isLoading = true
        errorMessage = ""
        
        authService.register(
            email: email,
            password: password,
            confirmPassword: confirmPassword
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] _ in
                self?.clearForm()
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - 登录
    func login() {
        guard validateLoginInput() else { return }
        
        isLoading = true
        errorMessage = ""
        
        authService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.clearForm()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 登出
    func logout() {
        authService.logout()
        clearForm()
    }
    
    // MARK: - 验证方法
    private func validateRegistrationInput() -> Bool {
        if email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            errorMessage = "请填写所有字段"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "请输入有效的邮箱地址"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "密码长度至少6位"
            return false
        }
        
        if password != confirmPassword {
            errorMessage = "两次输入的密码不一致"
            return false
        }
        
        return true
    }
    
    private func validateLoginInput() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "请输入邮箱和密码"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "请输入有效的邮箱地址"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
    }
}
