import SwiftUI
import Combine  // ✅ 添加 Combine 导入

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
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // 首页
                HomeView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        Text("首页")
                    }
                    .tag(0)
                
                // 支出记录
                ExpenseListView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
                        Text("记录")
                    }
                    .tag(1)
                
                // 添加支出
                AddExpenseView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "plus.circle.fill" : "plus.circle")
                        Text("添加")
                    }
                    .tag(2)
                
                // 预算管理
                SetBudgetView(viewModel: budgetViewModel)
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "chart.pie.fill" : "chart.pie")
                        Text("预算")
                    }
                    .tag(3)
                
                // 设置
                SettingsView()
                    .environmentObject(authViewModel)
                    .tabItem {
                        Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                        Text("设置")
                    }
                    .tag(4)
            }
            .accentColor(.systemBlue)
            
            // 自动识别功能覆盖层
            AutoRecognitionView()
                .allowsHitTesting(false) // 不阻止底层交互
        }
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

// MARK: - 统计分析视图
struct ExpenseStatsView: View {
    @StateObject private var statsViewModel = ExpenseStatsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let statsResponse = statsViewModel.stats {
                    let expenseStats = ExpenseStats(
                        categoryStats: [], // 需要转换CategoryStat类型
                        totalStats: TotalStat(
                            totalAmount: statsResponse.totalStats.totalAmount,
                            totalCount: statsResponse.totalStats.totalCount,
                            avgAmount: statsResponse.totalStats.avgAmount,
                            maxAmount: statsResponse.totalStats.maxAmount,
                            minAmount: statsResponse.totalStats.minAmount
                        ),
                        periodStats: [] // 需要转换PeriodStat类型
                    )
                    ExpenseStatsDashboardView(stats: expenseStats)
                } else if statsViewModel.isLoading {
                    ProgressView("加载统计数据...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("统计分析")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("查看详细的支出分析和趋势")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("刷新数据") {
                            statsViewModel.loadStats()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .navigationTitle("统计分析")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                statsViewModel.loadStats()
            }
        }
        .onAppear {
            statsViewModel.loadStats()
        }
    }
}

/**
 * 设置视图
 */
struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var budgetService = BudgetService.shared
    @StateObject private var autoRecognitionViewModel = AutoRecognitionViewModel()
    @State private var showingDeleteAccountConfirmation = false
    
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
                
                // 账号管理区域
                accountManagementSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDeleteAccountConfirmation) {
                AccountDeletionConfirmationView(
                    authViewModel: authViewModel,
                    isPresented: $showingDeleteAccountConfirmation
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
        } header: {
            Text("用户信息")
        }
    }
    
    // MARK: - 预算设置区域
    private var budgetSettingsSection: some View {
        Section {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
            }
            
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
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
            // 自动识别账单功能
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动识别账单")
                        .font(.body)
                    
                    Text("背面敲击3下识别屏幕上的账单信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $autoRecognitionViewModel.isEnabled)
                    .labelsHidden()
                    .onChange(of: autoRecognitionViewModel.isEnabled) { _, newValue in
                        if newValue != autoRecognitionViewModel.isEnabled {
                            autoRecognitionViewModel.toggleEnabled()
                        }
                    }
            }
            
            SettingsRow(
                icon: "moon.fill",
                title: "深色模式",
                color: .indigo,
                action: {}
            )
            
            SettingsRow(
                icon: "globe",
                title: "语言设置",
                color: .green,
                action: {}
            )
            
            SettingsRow(
                icon: "lock.fill",
                title: "隐私设置",
                color: .red,
                action: {}
            )
        } header: {
            Text("应用设置")
        }
        .alert("错误", isPresented: .constant(autoRecognitionViewModel.errorMessage != nil)) {
            Button("确定") {
                autoRecognitionViewModel.errorMessage = nil
            }
        } message: {
            Text(autoRecognitionViewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - 关于区域
    private var aboutSection: some View {
        Section {
            SettingsRow(
                icon: "questionmark.circle.fill",
                title: "帮助与支持",
                color: .blue,
                action: {}
            )
            
            SettingsRow(
                icon: "star.fill",
                title: "评价应用",
                color: .yellow,
                action: {}
            )
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
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
    
    // MARK: - 账号管理区域
    private var accountManagementSection: some View {
        Section {
            // 删除账号按钮
            Button(action: {
                showingDeleteAccountConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("删除账号")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
            
            // 退出登录按钮
            Button(action: {
                authViewModel.logout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("退出登录")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
        } header: {
            Text("账号管理")
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

// MARK: - 支出统计视图模型
class ExpenseStatsViewModel: ObservableObject {
    @Published var stats: ExpenseStatsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let expenseService: ExpenseServiceProtocol
    private var cancellables = Set<AnyCancellable>()  // ✅ 现在可以找到 AnyCancellable
    
    init(expenseService: ExpenseServiceProtocol = ExpenseService()) {
        self.expenseService = expenseService
        setupNotificationObservers()
    }
    
    deinit {
        print("📊 ExpenseStatsViewModel销毁")
        NotificationCenter.default.removeObserver(self)
    }
    
    /**
     * 设置通知监听
     * 监听支出数据变化通知并刷新统计数据
     */
    private func setupNotificationObservers() {
        // 监听支出数据变化通知
        NotificationCenter.default.addObserver(
            forName: .expenseDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📢 ExpenseStatsViewModel收到支出数据变化通知")
            if let operationType = notification.userInfo?[NotificationUserInfoKeys.operationType] as? String {
                print("📊 操作类型: \(operationType)")
                // 无论是创建、更新还是删除支出，都需要刷新统计数据
                self?.loadStats()
            }
        }
    }
    
    func loadStats() {
        isLoading = true
        errorMessage = nil
        
        // ✅ 调用支出统计接口，传入默认参数
        expenseService.getExpenseStatistics(startDate: nil, endDate: nil, period: "month")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] stats in
                    self?.stats = stats
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 预览
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 已登录状态
            ContentView()
                .previewDisplayName("已登录")
            
            // 深色模式
            ContentView()
                .preferredColorScheme(.dark)
                .previewDisplayName("深色模式")
        }
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
            .environmentObject(BudgetViewModel())
            .previewDisplayName("主应用界面")
    }
}
#endif
