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
                MainTabView()
                    .environmentObject(budgetViewModel)
                    .onAppear {
                        print("✅ 显示主应用界面 - 用户已认证")
                        print("👤 当前用户: \(authService.currentUser?.email ?? "nil")")
                    }
            } else {
                // 未登录：显示认证界面
                AuthenticationView()
                    .onAppear {
                        print("🔐 显示认证界面 - 用户未认证")
                    }
            }
        }
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
        ContentView()
    }
}
#endif

// MARK: - 数据库测试函数

/**
 * 执行数据库连接测试
 */
func runDatabaseConnectionTest() async {
    print("\n🚀 开始数据库连接测试")
    print("================================")
    
    let supabaseManager = SupabaseManager.shared
    
    // 打印调试信息
    print("📋 Supabase 配置信息:")
    supabaseManager.printDebugInfo()
    
    // 1. 配置验证
    print("\n🔍 步骤 1: 配置验证")
    let configValid = supabaseManager.checkConfiguration()
    print(configValid ? "✅ 配置验证: 成功" : "❌ 配置验证: 失败")
    
    // 2. 网络连通性测试
    print("\n🌐 步骤 2: 网络连通性测试")
    let networkReachable = await supabaseManager.testConfiguration()
    print(networkReachable ? "✅ 网络连通性: 成功" : "❌ 网络连通性: 失败")
    
    // 3. 客户端初始化测试
    print("\n🔧 步骤 3: 客户端初始化测试")
    do {
        let client = supabaseManager.client
        print("✅ 客户端初始化: 成功")
        print("   客户端已成功创建")
    } catch {
        print("❌ 客户端初始化: 失败")
        print("   错误: \(error.localizedDescription)")
    }
    
    // 4. 数据库连接测试
    print("\n🗄️ 步骤 4: 数据库连接测试")
    let dbConnected = await supabaseManager.testDatabaseConnection()
    print(dbConnected ? "✅ 数据库连接: 成功" : "❌ 数据库连接: 失败")
    
    // 5. 认证服务测试
    print("\n🔐 步骤 5: 认证服务测试")
    let authConnected = await supabaseManager.testAuthConnection()
    print(authConnected ? "✅ 认证服务: 成功" : "❌ 认证服务: 失败")
    
    // 6. 数据库表结构检查
    print("\n📊 步骤 6: 数据库表结构检查")
    let tables = await supabaseManager.checkDatabaseTables()
    if !tables.isEmpty {
        print("✅ 数据库表: 找到 \(tables.count) 个表")
        print("   表: \(tables.joined(separator: ", "))")
    } else {
        print("⚠️ 数据库表: 未找到预期表")
        print("   这可能是正常的，如果还未创建数据库表结构")
    }
    
    // 测试总结
    print("\n================================")
    print("🏁 数据库连接测试完成")
    
    let successCount = [configValid, networkReachable, dbConnected, authConnected].filter { $0 }.count
    let totalTests = 4
    print("📈 测试结果: \(successCount)/\(totalTests) 项成功")
    
    if successCount == totalTests {
        print("🎉 所有核心测试通过！数据库连接正常")
        print("✨ Supabase 集成已准备就绪")
    } else if successCount >= 2 {
        print("⚠️ 部分测试成功，基本功能可用")
        print("💡 建议检查失败的项目以优化连接")
    } else {
        print("❌ 多项测试失败，请检查配置")
        print("🔧 建议检查网络连接和 Supabase 配置")
    }
    
    print("================================\n")
}

/**
 * 执行 Supabase 健康检查
 */
func runSupabaseHealthCheck() async {
    print("\n🏥 开始 Supabase 完整健康检查")
    print("================================")
    
    let supabaseManager = SupabaseManager.shared
    let healthResult = await supabaseManager.performHealthCheck()
    
    // 打印详细报告
    healthResult.printSummary()
}

/**
 * 查看登录调试日志
 */
func viewLoginDebugLog() {
    print("\n📋 查看登录调试日志")
    print("================================")
    
    let logger = LoginDebugLogger.shared
    let logContent = logger.getLogContent()
    
    if logContent.isEmpty {
        print("📝 暂无登录调试日志")
    } else {
        print("📝 登录调试日志内容:")
        print(logContent)
        
        // 保存日志到文件
        if let filePath = logger.saveLogToFile() {
            print("\n💾 日志已保存到文件: \(filePath)")
        }
    }
    
    print("================================\n")
}
