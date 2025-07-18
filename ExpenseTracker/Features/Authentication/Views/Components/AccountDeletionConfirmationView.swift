import SwiftUI

/**
 * 账户删除确认视图
 */
struct AccountDeletionConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var error: Error?
    
    init(authViewModel: AuthViewModel, isPresented: Binding<Bool>) {
        self.authViewModel = authViewModel
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 30)
                
                // 警告标题
                Text("危险操作")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 警告描述
                Text("删除账户是不可逆操作，所有数据将被永久删除且无法恢复。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 确认输入框
                VStack(alignment: .leading) {
                    Text("请输入\"DELETE\"以确认删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("DELETE", text: $confirmText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 错误信息
                if let error = error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // 删除按钮
                Button(action: deleteAccount) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("删除我的账户")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(confirmText == "DELETE" ? Color.red : Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(confirmText != "DELETE" || isDeleting)
                
                Spacer()
            }
            .navigationBarTitle("删除账户", displayMode: .inline)
            .navigationBarItems(leading: Button("取消") {
                isPresented = false
            })
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        error = nil
        
        authViewModel.deleteAccount { result in
            isDeleting = false
            
            switch result {
            case .success:
                // 账户删除成功，会自动登出
                isPresented = false
            case .failure(let error):
                self.error = error
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