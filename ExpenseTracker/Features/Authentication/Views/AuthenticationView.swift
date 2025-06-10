import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 自定义标签选择器
                customTabPicker
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    LoginView(viewModel: viewModel)
                        .tag(0)
                    
                    RegisterView(viewModel: viewModel)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - 自定义标签选择器
    private var customTabPicker: some View {
        HStack(spacing: 0) {
            TabButton(title: "登录", isSelected: selectedTab == 0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 0
                }
                viewModel.errorMessage = ""
            }
            
            TabButton(title: "注册", isSelected: selectedTab == 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 1
                }
                viewModel.errorMessage = ""
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(Color.systemBackground)
    }
}

// MARK: - 标签按钮组件
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .systemBlue : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color.systemBlue : Color.clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 预览
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
