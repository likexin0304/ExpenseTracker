import SwiftUI

/**
 * 设置视图
 */
struct SettingsView: View {
    @StateObject private var authViewModel = AuthViewModel.shared
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var autoOCRViewModel = AutoOCRViewModel()
    @State private var showDeleteAccountConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                userProfileSection
                
                // 预算设置区域
                budgetSettingsSection
                
                // 智能识别设置区域
                autoOCRSettingsSection
                
                // 应用设置区域
                appSettingsSection
                
                // 数据库测试区域
                databaseTestSection
                
                // 关于区域
                aboutSection
                
                // 账号管理区域
                accountManagementSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showDeleteAccountConfirmation) {
                AccountDeletionConfirmationView(
                    authViewModel: authViewModel,
                    isPresented: $showDeleteAccountConfirmation
                )
            }
        }
    }
    
    // MARK: - 用户信息区域
    private var userProfileSection: some View {
        Section {
            HStack(spacing: 16) {
                // 用户头像
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(AuthService.shared.currentUser?.email ?? "未知用户")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("记账用户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 预算设置区域
    private var budgetSettingsSection: some View {
        Section(header: Text("预算设置")) {
            NavigationLink(destination: SetBudgetView(viewModel: BudgetViewModel())) {
                HStack {
                    Image(systemName: "chart.pie")
                        .foregroundColor(.purple)
                    Text("设置预算")
                }
            }
            
            if let currentBudget = budgetService.currentBudget {
                HStack {
                    Text("当前预算")
                    Spacer()
                    Text("¥\(currentBudget.amount, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - 智能识别设置区域
    private var autoOCRSettingsSection: some View {
        Section(header: Text("智能识别")) {
            NavigationLink(destination: AutomationSettingsView()) {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.blue)
                    Text("自动识别设置")
                }
            }
            
            Toggle("启用背敲检测", isOn: $autoOCRViewModel.automationSettings.enableBackTap)
            
            if autoOCRViewModel.automationSettings.debugMode {
                HStack {
                    Image(systemName: "ladybug")
                        .foregroundColor(.orange)
                    Text("调试模式已启用")
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - 应用设置区域
    private var appSettingsSection: some View {
        Section(header: Text("应用设置")) {
            NavigationLink(destination: Text("主题设置")) {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.pink)
                    Text("主题设置")
                }
            }
            
            NavigationLink(destination: Text("通知设置")) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.orange)
                    Text("通知设置")
                }
            }
            
            NavigationLink(destination: Text("数据导出")) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                    Text("数据导出")
                }
            }
        }
    }
    
    // MARK: - 数据库测试区域
    private var databaseTestSection: some View {
        Section(header: Text("数据库")) {
            NavigationLink(destination: Text("数据库管理")) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.gray)
                    Text("数据库管理")
                }
            }
            
            Button(action: {
                // 清除缓存
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("清除缓存")
                }
            }
        }
    }
    
    // MARK: - 关于区域
    private var aboutSection: some View {
        Section(header: Text("关于")) {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            NavigationLink(destination: Text("隐私政策")) {
                Text("隐私政策")
            }
            
            NavigationLink(destination: Text("用户协议")) {
                Text("用户协议")
            }
        }
    }
    
    // MARK: - 账号管理区域
    private var accountManagementSection: some View {
        Section {
            Button(action: {
                authViewModel.logout()
            }) {
                HStack {
                    Spacer()
                    Text("退出登录")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            
            Button(action: {
                showDeleteAccountConfirmation = true
            }) {
                HStack {
                    Spacer()
                    Text("删除账号")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
}

/**
 * 设置行组件
 */
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 