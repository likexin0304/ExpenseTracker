import SwiftUI

struct AccountDeletionConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var confirmationText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 20)
                
                // 警告标题
                Text("删除账号")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 警告内容
                VStack(spacing: 16) {
                    Text("你正在删除账号，账号删除后无法找回相关数据，请你认真思考并确认该操作。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    Text("请输入「我确认」来确认执行账号删除")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // 确认输入框
                VStack(alignment: .leading, spacing: 8) {
                    TextField("请输入：我确认", text: $confirmationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !authViewModel.deleteAccountErrorMessage.isEmpty {
                        Text(authViewModel.deleteAccountErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 按钮区域
                VStack(spacing: 12) {
                    // 删除按钮
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        authViewModel.deleteAccount(confirmationText: confirmationText)
                    }) {
                        HStack {
                            if authViewModel.isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(authViewModel.isDeletingAccount ? "删除中..." : "确认删除账号")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(confirmationText.isEmpty || authViewModel.isDeletingAccount)
                    .opacity(confirmationText.isEmpty ? 0.6 : 1.0)
                    
                    // 取消按钮
                    Button("取消") {
                        isPresented = false
                        authViewModel.clearDeleteAccountForm()
                        confirmationText = ""
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .disabled(authViewModel.isDeletingAccount)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .onAppear {
            isTextFieldFocused = true
            authViewModel.clearDeleteAccountForm()
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                // 删除成功，关闭弹窗
                isPresented = false
            }
        }
    }
}

// MARK: - 预览
#if DEBUG
struct AccountDeletionConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        AccountDeletionConfirmationView(
            authViewModel: AuthViewModel(),
            isPresented: .constant(true)
        )
    }
}
#endif 