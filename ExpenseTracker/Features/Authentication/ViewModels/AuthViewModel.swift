import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    // 删除账号相关状态
    @Published var isDeletingAccount = false
    @Published var deleteAccountErrorMessage = ""
    
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🔵 AuthViewModel 初始化")
        setupAuthStateListener()
    }
    
    deinit {
        print("🔴 AuthViewModel 即将释放")
        cancellables.removeAll()
    }
    
    // MARK: - 注册
    func register() {
        print("🔵 AuthViewModel.register() 被调用")
        print("📧 邮箱: \(email), 密码长度: \(password.count)")
        
        guard validateRegistrationInput() else { 
            print("❌ 注册表单验证失败")
            return 
        }
        
        print("✅ 注册表单验证通过，开始调用AuthService")
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
        print("🔵 AuthViewModel.login() 被调用")
        
        guard validateLoginInput() else {
            print("❌ 登录表单验证失败")
            return
        }
        
        print("✅ 登录表单验证通过，开始调用AuthService")
        isLoading = true
        errorMessage = ""
        
        authService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        print("❌ 登录失败: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self = self else { return }
                    
                    print("✅ 登录成功")
                    self.clearForm()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 登出
    func logout() {
        authService.logout()
        clearForm()
    }
    
    // MARK: - 删除账号
    func deleteAccount(confirmationText: String) {
        print("🔵 AuthViewModel.deleteAccount() 被调用")
        print("🗑️ 确认文本: \(confirmationText)")
        
        guard !confirmationText.isEmpty else {
            deleteAccountErrorMessage = "请输入确认文本"
            return
        }
        
        guard confirmationText.contains("我确认") else {
            deleteAccountErrorMessage = "请输入包含「我确认」的文本"
            return
        }
        
        print("✅ 删除账号验证通过，开始调用AuthService")
        isDeletingAccount = true
        deleteAccountErrorMessage = ""
        
        authService.deleteAccount(confirmationText: confirmationText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isDeletingAccount = false
                    
                    if case .failure(let error) = completion {
                        print("❌ 删除账号失败: \(error.localizedDescription)")
                        self.deleteAccountErrorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self = self else { return }
                    
                    print("✅ 账号删除成功")
                    // 删除成功后会自动触发登出，不需要手动处理
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 清除删除账号表单
    func clearDeleteAccountForm() {
        deleteAccountErrorMessage = ""
        isDeletingAccount = false
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
        if email.isEmpty {
            errorMessage = "请输入邮箱"
            return false
        }
        
        if !email.contains("@") {
            errorMessage = "请输入有效的邮箱地址"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "请输入密码"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "密码至少需要6位"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    // MARK: - 私有方法
    private func setupAuthStateListener() {
        // 监听认证状态变化
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                self.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
        deleteAccountErrorMessage = ""
    }
}
