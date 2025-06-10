import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 顶部logo和标题区域
                headerSection
                
                // 登录表单
                loginForm
                
                // 分割线和其他登录方式
                dividerSection
                
                // 微信登录按钮
                wechatLoginButton
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
        }
        .background(Color.systemBackground.ignoresSafeArea())
        .onSubmit {
            handleSubmit()
        }
    }
    
    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App图标
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.systemBlue)
            
            VStack(spacing: 8) {
                Text("欢迎回来")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("登录您的记账账户")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 登录表单
    private var loginForm: some View {
        VStack(spacing: 20) {
            CustomTextField(
                title: "邮箱",
                placeholder: "请输入您的邮箱",
                text: $viewModel.email,
                keyboardType: .emailAddress
            )
            .focused($focusedField, equals: .email)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            
            CustomTextField(
                title: "密码",
                placeholder: "请输入密码",
                text: $viewModel.password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            
            // 错误提示
            if !viewModel.errorMessage.isEmpty {
                ErrorMessageView(message: viewModel.errorMessage)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 登录按钮
            LoadingButton(
                title: "登录",
                isLoading: viewModel.isLoading,
                action: viewModel.login
            )
            .padding(.top, 8)
        }
        .cardStyle()
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }
    
    // MARK: - 分割线
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color.systemGray4)
                .frame(height: 1)
            
            Text("或")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(Color.systemGray4)
                .frame(height: 1)
        }
    }
    
    // MARK: - 微信登录
    private var wechatLoginButton: some View {
        Button(action: {
            // TODO: 实现微信登录
        }) {
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("使用微信登录")
                    .fontWeight(.medium)
            }
        }
        .secondaryButtonStyle()
    }
    
    // MARK: - 私有方法
    private func handleSubmit() {
        switch focusedField {
        case .email:
            focusedField = .password
        case .password:
            viewModel.login()
        case .none:
            break
        }
    }
}
