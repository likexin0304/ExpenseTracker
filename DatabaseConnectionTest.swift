import Foundation
import SwiftUI

/**
 * 数据库连接测试
 * 专门用于测试 Supabase 数据库的实际连接
 */

// MARK: - 简单的命令行测试函数

/**
 * 执行简单的数据库连接测试
 * 可以在控制台中直接调用
 */
func runDatabaseConnectionTest() async {
    print("🚀 开始数据库连接测试")
    print("================================")
    
    let supabaseManager = SupabaseManager.shared
    
    // 1. 配置验证
    print("🔍 测试配置验证...")
    let configValid = supabaseManager.checkConfiguration()
    print(configValid ? "✅ 配置验证: 成功" : "❌ 配置验证: 失败")
    
    // 2. 网络连通性
    print("🌐 测试网络连通性...")
    let networkReachable = await supabaseManager.testConfiguration()
    print(networkReachable ? "✅ 网络连通性: 成功" : "❌ 网络连通性: 失败")
    
    // 3. 客户端初始化
    print("🔧 测试客户端初始化...")
    do {
        let client = supabaseManager.client
        let url = client.supabaseURL.absoluteString
        print("✅ 客户端初始化: 成功")
        print("   连接到: \(url)")
    } catch {
        print("❌ 客户端初始化: 失败 - \(error.localizedDescription)")
    }
    
    // 4. 数据库连接
    print("🗄️ 测试数据库连接...")
    let dbConnected = await supabaseManager.testDatabaseConnection()
    print(dbConnected ? "✅ 数据库连接: 成功" : "❌ 数据库连接: 失败")
    
    // 5. 认证服务
    print("🔐 测试认证服务...")
    let authConnected = await supabaseManager.testAuthConnection()
    print(authConnected ? "✅ 认证服务: 成功" : "❌ 认证服务: 失败")
    
    // 6. 表结构检查
    print("📊 检查数据库表结构...")
    let tables = await supabaseManager.checkDatabaseTables()
    if !tables.isEmpty {
        print("✅ 数据库表: 找到 \(tables.count) 个表")
        print("   表: \(tables.joined(separator: ", "))")
    } else {
        print("⚠️ 数据库表: 未找到预期表，可能需要创建")
    }
    
    print("================================")
    print("🏁 数据库连接测试完成")
    
    // 总结
    let successCount = [configValid, networkReachable, dbConnected, authConnected].filter { $0 }.count
    let totalTests = 4
    print("📈 测试结果: \(successCount)/\(totalTests) 项成功")
    
    if successCount == totalTests {
        print("🎉 所有测试通过！数据库连接正常")
    } else {
        print("⚠️ 部分测试失败，请检查配置和网络")
    }
}

/**
 * 执行健康检查
 */
func runHealthCheck() async {
    print("🏥 执行 Supabase 健康检查...")
    
    let supabaseManager = SupabaseManager.shared
    let healthResult = await supabaseManager.performHealthCheck()
    
    // 打印详细报告
    healthResult.printSummary()
}

// MARK: - 数据库连接测试类（完整版本）

/**
 * 数据库连接测试
 * 专门用于测试 Supabase 数据库的实际连接
 * 
 * 功能：
 * - 测试 Supabase 客户端初始化
 * - 测试数据库连接状态
 * - 测试认证服务连接
 * - 检查数据库表结构
 * - 执行健康检查
 */
class DatabaseConnectionTest: ObservableObject {
    
    @Published var isLoading = false
    @Published var testResults: [TestResult] = []
    @Published var overallStatus: TestStatus = .pending
    
    private let supabaseManager = SupabaseManager.shared
    
    enum TestStatus {
        case pending
        case running
        case success
        case failed
        case warning
        
        var emoji: String {
            switch self {
            case .pending: return "⏳"
            case .running: return "🔄"
            case .success: return "✅"
            case .failed: return "❌"
            case .warning: return "⚠️"
            }
        }
        
        var description: String {
            switch self {
            case .pending: return "等待测试"
            case .running: return "测试中"
            case .success: return "测试成功"
            case .failed: return "测试失败"
            case .warning: return "警告"
            }
        }
    }
    
    struct TestResult {
        let name: String
        let status: TestStatus
        let message: String
        let details: String?
        let timestamp: Date
        
        init(name: String, status: TestStatus, message: String, details: String? = nil) {
            self.name = name
            self.status = status
            self.message = message
            self.details = details
            self.timestamp = Date()
        }
    }
    
    // MARK: - 主要测试方法
    
    /**
     * 执行完整的数据库连接测试
     */
    @MainActor
    func runFullConnectionTest() async {
        isLoading = true
        overallStatus = .running
        testResults.removeAll()
        
        print("🚀 开始完整数据库连接测试")
        print("================================")
        
        // 1. 配置验证测试
        await testConfiguration()
        
        // 2. 网络连通性测试
        await testNetworkConnectivity()
        
        // 3. Supabase 客户端初始化测试
        await testSupabaseClientInitialization()
        
        // 4. 数据库连接测试
        await testDatabaseConnection()
        
        // 5. 认证服务测试
        await testAuthenticationService()
        
        // 6. 数据库表结构检查
        await testDatabaseTableStructure()
        
        // 7. 计算总体状态
        calculateOverallStatus()
        
        isLoading = false
        
        print("================================")
        print("🏁 数据库连接测试完成")
        printTestSummary()
    }
    
    /**
     * 快速连接测试
     */
    @MainActor
    func runQuickConnectionTest() async {
        isLoading = true
        overallStatus = .running
        testResults.removeAll()
        
        print("⚡ 开始快速连接测试")
        
        // 只执行关键测试
        await testConfiguration()
        await testSupabaseClientInitialization()
        await testDatabaseConnection()
        
        calculateOverallStatus()
        isLoading = false
        
        print("⚡ 快速连接测试完成")
    }
    
    // MARK: - 具体测试方法
    
    /**
     * 测试配置验证
     */
    private func testConfiguration() async {
        let testName = "配置验证"
        print("🔍 \(testName)...")
        
        let isValid = supabaseManager.checkConfiguration()
        
        if isValid {
            let result = TestResult(
                name: testName,
                status: .success,
                message: "Supabase 配置验证成功",
                details: "URL 和 API Key 格式正确"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功")
        } else {
            let result = TestResult(
                name: testName,
                status: .failed,
                message: "Supabase 配置验证失败",
                details: "请检查 Info.plist 中的配置"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("❌ \(testName): 失败")
        }
    }
    
    /**
     * 测试网络连通性
     */
    private func testNetworkConnectivity() async {
        let testName = "网络连通性"
        print("🌐 \(testName)...")
        
        let isReachable = await supabaseManager.testConfiguration()
        
        if isReachable {
            let result = TestResult(
                name: testName,
                status: .success,
                message: "Supabase 服务可达",
                details: "网络连接正常"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功")
        } else {
            let result = TestResult(
                name: testName,
                status: .failed,
                message: "Supabase 服务不可达",
                details: "请检查网络连接和服务状态"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("❌ \(testName): 失败")
        }
    }
    
    /**
     * 测试 Supabase 客户端初始化
     */
    private func testSupabaseClientInitialization() async {
        let testName = "客户端初始化"
        print("🔧 \(testName)...")
        
        do {
            // 尝试访问客户端
            let client = supabaseManager.client
            let url = client.supabaseURL.absoluteString
            
            let result = TestResult(
                name: testName,
                status: .success,
                message: "Supabase 客户端初始化成功",
                details: "连接到: \(url)"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功")
            
        } catch {
            let result = TestResult(
                name: testName,
                status: .failed,
                message: "Supabase 客户端初始化失败",
                details: "错误: \(error.localizedDescription)"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("❌ \(testName): 失败 - \(error.localizedDescription)")
        }
    }
    
    /**
     * 测试数据库连接
     */
    private func testDatabaseConnection() async {
        let testName = "数据库连接"
        print("🗄️ \(testName)...")
        
        let isConnected = await supabaseManager.testDatabaseConnection()
        
        if isConnected {
            let result = TestResult(
                name: testName,
                status: .success,
                message: "数据库连接成功",
                details: "可以执行数据库查询"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功")
        } else {
            let result = TestResult(
                name: testName,
                status: .failed,
                message: "数据库连接失败",
                details: "无法执行数据库查询，可能是权限或表不存在"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("❌ \(testName): 失败")
        }
    }
    
    /**
     * 测试认证服务
     */
    private func testAuthenticationService() async {
        let testName = "认证服务"
        print("🔐 \(testName)...")
        
        let isConnected = await supabaseManager.testAuthConnection()
        
        if isConnected {
            let result = TestResult(
                name: testName,
                status: .success,
                message: "认证服务连接成功",
                details: "可以访问认证功能"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功")
        } else {
            let result = TestResult(
                name: testName,
                status: .failed,
                message: "认证服务连接失败",
                details: "无法访问认证功能"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("❌ \(testName): 失败")
        }
    }
    
    /**
     * 测试数据库表结构
     */
    private func testDatabaseTableStructure() async {
        let testName = "数据库表结构"
        print("📊 \(testName)...")
        
        let availableTables = await supabaseManager.checkDatabaseTables()
        
        if !availableTables.isEmpty {
            let result = TestResult(
                name: testName,
                status: .success,
                message: "找到 \(availableTables.count) 个可用表",
                details: "表: \(availableTables.joined(separator: ", "))"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("✅ \(testName): 成功 - 找到 \(availableTables.count) 个表")
        } else {
            let result = TestResult(
                name: testName,
                status: .warning,
                message: "未找到预期的数据库表",
                details: "可能需要创建数据库表结构"
            )
            await MainActor.run {
                testResults.append(result)
            }
            print("⚠️ \(testName): 警告 - 未找到表")
        }
    }
    
    // MARK: - 辅助方法
    
    /**
     * 计算总体状态
     */
    private func calculateOverallStatus() {
        let hasFailure = testResults.contains { $0.status == .failed }
        let hasWarning = testResults.contains { $0.status == .warning }
        
        if hasFailure {
            overallStatus = .failed
        } else if hasWarning {
            overallStatus = .warning
        } else if testResults.allSatisfy({ $0.status == .success }) {
            overallStatus = .success
        } else {
            overallStatus = .pending
        }
    }
    
    /**
     * 打印测试总结
     */
    private func printTestSummary() {
        print("\n📊 测试总结")
        print("========================")
        
        for result in testResults {
            print("\(result.status.emoji) \(result.name): \(result.message)")
            if let details = result.details {
                print("   详情: \(details)")
            }
        }
        
        print("========================")
        print("🏥 总体状态: \(overallStatus.emoji) \(overallStatus.description)")
        
        let successCount = testResults.filter { $0.status == .success }.count
        let failureCount = testResults.filter { $0.status == .failed }.count
        let warningCount = testResults.filter { $0.status == .warning }.count
        
        print("📈 统计: \(successCount) 成功, \(failureCount) 失败, \(warningCount) 警告")
        print("========================\n")
    }
    
    /**
     * 获取测试结果摘要
     */
    func getTestSummary() -> String {
        let successCount = testResults.filter { $0.status == .success }.count
        let failureCount = testResults.filter { $0.status == .failed }.count
        let warningCount = testResults.filter { $0.status == .warning }.count
        
        return "\(successCount) 成功, \(failureCount) 失败, \(warningCount) 警告"
    }
}

// MARK: - SwiftUI 测试界面

struct DatabaseConnectionTestView: View {
    @StateObject private var tester = DatabaseConnectionTest()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 状态标题
                VStack {
                    Text(tester.overallStatus.emoji)
                        .font(.system(size: 60))
                    
                    Text("数据库连接测试")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(tester.overallStatus.description)
                        .font(.headline)
                        .foregroundColor(statusColor)
                }
                .padding()
                
                // 测试按钮
                HStack(spacing: 15) {
                    Button("完整测试") {
                        Task {
                            await tester.runFullConnectionTest()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tester.isLoading)
                    
                    Button("快速测试") {
                        Task {
                            await tester.runQuickConnectionTest()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(tester.isLoading)
                }
                
                // 加载指示器
                if tester.isLoading {
                    ProgressView("测试进行中...")
                        .padding()
                }
                
                // 测试结果列表
                List(tester.testResults, id: \.name) { result in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(result.status.emoji)
                            Text(result.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(result.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let details = result.details {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // 摘要信息
                if !tester.testResults.isEmpty {
                    Text("摘要: \(tester.getTestSummary())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("连接测试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusColor: Color {
        switch tester.overallStatus {
        case .success:
            return .green
        case .failed:
            return .red
        case .warning:
            return .orange
        case .running:
            return .blue
        case .pending:
            return .gray
        }
    }
} 