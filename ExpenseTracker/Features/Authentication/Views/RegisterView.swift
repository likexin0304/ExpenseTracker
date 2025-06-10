import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 顶部标题
                headerSection
                
                // 注册表单
                registerForm
                
                // 分割线和其他注册方式
                dividerSection
                
                // 微信注册按钮
                wechatRegisterButton
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .background(Color.systemBackground.ignoresSafeArea())
        .onSubmit {
            handleSubmit()
        }
    }
    
    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.systemBlue)
            
            VStack(spacing: 8) {
                Text("创建账户")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("开始您的记账之旅")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 注册表单
    private var registerForm: some View {
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
                placeholder: "至少6位密码",
                text: $viewModel.password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            
            CustomTextField(
                title: "确认密码",
                placeholder: "再次输入密码",
                text: $viewModel.confirmPassword,
                isSecure: true
            )
            .focused($focusedField, equals: .confirmPassword)
            
            // 错误提示
            if !viewModel.errorMessage.isEmpty {
                ErrorMessageView(message: viewModel.errorMessage)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 服务条款
            termsAndConditions
            
            // 注册按钮
            LoadingButton(
                title: "创建账户",
                isLoading: viewModel.isLoading,
                action: viewModel.register
            )
            .padding(.top, 8)
        }
        .cardStyle()
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }
    
    // MARK: - 服务条款
    private var termsAndConditions: some View {
        Text("注册即表示您同意我们的服务条款和隐私政策")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
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
    
    // MARK: - 微信注册
    private var wechatRegisterButton: some View {
        Button(action: {
            // TODO: 实现微信注册
        }) {
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("使用微信注册")
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
            focusedField = .confirmPassword
        case .confirmPassword:
            viewModel.register()
        case .none:
            break
        }
    }
}
