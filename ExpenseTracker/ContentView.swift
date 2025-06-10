import SwiftUI

/**
 * 应用主视图
 * 根据用户认证状态显示不同的界面
 */
struct ContentView: View {
    // MARK: - 状态管理
    @StateObject private var authService = AuthService.shared
    @StateObject private var budgetViewModel = BudgetViewModel()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 已登录：显示主应用界面
                MainAppView()
                    .environmentObject(budgetViewModel)
            } else {
                // 未登录：显示认证界面
                AuthenticationView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .onAppear {
            print("📱 ContentView出现")
        }
    }
}

/**
 * 主应用视图
 * 包含底部导航栏的完整应用界面
 */
struct MainAppView: View {
    // MARK: - 状态管理
    @EnvironmentObject var budgetViewModel: BudgetViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("首页")
                }
                .tag(0)
            
            // 支出记录（待实现）
            ExpenseListView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
                    Text("记录")
                }
                .tag(1)
            
            // 添加支出（待实现）
            AddExpenseView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("添加")
                }
                .tag(2)
            
            // 统计分析（待实现）
            StatisticsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "chart.bar.fill" : "chart.bar")
                    Text("统计")
                }
                .tag(3)
            
            // 设置
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gear.fill" : "gear")
                    Text("设置")
                }
                .tag(4)
        }
        .accentColor(.systemBlue)
        .onAppear {
            // 配置TabBar外观
            configureTabBarAppearance()
        }
    }
    
    // MARK: - TabBar外观配置
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // 设置选中状态的颜色
        appearance.selectionIndicatorTintColor = UIColor.systemBlue
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - 临时占位视图（待实现的功能）

/**
 * 支出列表视图（占位符）
 */
struct ExpenseListView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 80))
                    .foregroundColor(.systemGray3)
                
                VStack(spacing: 8) {
                    Text("支出记录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("这里将显示您的支出历史记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text("功能开发中...")
                    .font(.caption)
                    .foregroundColor(.systemBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.systemBlue.opacity(0.1))
                    )
            }
            .navigationTitle("支出记录")
        }
    }
}

/**
 * 添加支出视图（占位符）
 */
struct AddExpenseView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.systemGray3)
                
                VStack(spacing: 8) {
                    Text("添加支出")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("快速记录您的消费支出")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text("功能开发中...")
                    .font(.caption)
                    .foregroundColor(.systemBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.systemBlue.opacity(0.1))
                    )
            }
            .navigationTitle("添加支出")
        }
    }
}

/**
 * 统计分析视图（占位符）
 */
struct StatisticsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 80))
                    .foregroundColor(.systemGray3)
                
                VStack(spacing: 8) {
                    Text("统计分析")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("查看详细的支出分析和趋势")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text("功能开发中...")
                    .font(.caption)
                    .foregroundColor(.systemBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.systemBlue.opacity(0.1))
                    )
            }
            .navigationTitle("统计分析")
        }
    }
}

/**
 * 设置视图
 */
struct SettingsView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var budgetService = BudgetService.shared
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                userProfileSection
                
                // 预算设置区域
                budgetSettingsSection
                
                // 应用设置区域
                appSettingsSection
                
                // 关于区域
                aboutSection
                
                // 登出区域
                logoutSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - 用户信息区域
    private var userProfileSection: some View {
        Section {
            HStack(spacing: 16) {
                // 用户头像
                Circle()
                    .fill(Color.systemBlue.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.systemBlue)
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
        } header: {
            Text("用户信息")
        }
    }
    
    // MARK: - 预算设置区域
    private var budgetSettingsSection: some View {
        Section {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.systemBlue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前预算")
                        .font(.body)
                    
                    if budgetService.hasBudget {
                        Text(budgetService.formatCurrency(budgetService.currentBudgetAmount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("未设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(budgetService.hasBudget ? "修改" : "设置")
                    .font(.subheadline)
                    .foregroundColor(.systemBlue)
            }
            
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.systemOrange)
                    .frame(width: 24)
                
                Text("预算提醒")
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
            }
        } header: {
            Text("预算设置")
        }
    }
    
    // MARK: - 应用设置区域
    private var appSettingsSection: some View {
        Section {
            SettingsRow(
                icon: "moon.fill",
                title: "深色模式",
                color: .systemIndigo,
                action: {}
            )
            
            SettingsRow(
                icon: "globe",
                title: "语言设置",
                color: .systemGreen,
                action: {}
            )
            
            SettingsRow(
                icon: "lock.fill",
                title: "隐私设置",
                color: .systemRed,
                action: {}
            )
        } header: {
            Text("应用设置")
        }
    }
    
    // MARK: - 关于区域
    private var aboutSection: some View {
        Section {
            SettingsRow(
                icon: "questionmark.circle.fill",
                title: "帮助与支持",
                color: .systemBlue,
                action: {}
            )
            
            SettingsRow(
                icon: "star.fill",
                title: "评价应用",
                color: .systemYellow,
                action: {}
            )
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.systemGray)
                    .frame(width: 24)
                
                Text("版本")
                
                Spacer()
                
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("关于")
        }
    }
    
    // MARK: - 登出区域
    private var logoutSection: some View {
        Section {
            Button(action: {
                authViewModel.logout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.systemRed)
                        .frame(width: 24)
                    
                    Text("退出登录")
                        .foregroundColor(.systemRed)
                    
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

// MARK: - 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
