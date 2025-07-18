import Foundation
import Supabase

/**
 * Supabase 管理器
 * 负责初始化和管理 Supabase 客户端
 * 提供统一的 Supabase 服务访问入口
 * 
 * 状态：完全激活，支持实际数据库连接
 */
class SupabaseManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SupabaseManager()
    
    // MARK: - Properties
    private let supabaseUrl: String
    private let supabaseAnonKey: String
    
    // Supabase 客户端
    private var _client: SupabaseClient?
    
    // MARK: - Computed Properties
    var client: SupabaseClient {
        if let existingClient = _client {
            return existingClient
        }
        
        // 创建新的客户端
        guard let url = URL(string: supabaseUrl) else {
            fatalError("❌ 无效的 Supabase URL: \(supabaseUrl)")
        }
        
        let newClient = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey)
        _client = newClient
        print("✅ Supabase 客户端初始化成功")
        return newClient
    }
    
    // MARK: - Initialization
    private init() {
        // 从 Info.plist 加载配置
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("❌ 无法加载 Supabase 配置，请检查 Info.plist 中的 SUPABASE_URL 和 SUPABASE_ANON_KEY")
        }
        
        self.supabaseUrl = url
        self.supabaseAnonKey = key
        
        print("✅ SupabaseManager 配置加载成功")
        print("🌐 Supabase URL: \(url)")
        print("🔑 API Key: \(String(key.prefix(20)))...")
        
        // 验证配置格式
        validateConfiguration()
    }
    
    // MARK: - Configuration Validation
    private func validateConfiguration() {
        // 验证 URL 格式
        guard URL(string: supabaseUrl) != nil else {
            fatalError("❌ Supabase URL 格式无效: \(supabaseUrl)")
        }
        
        // 验证 API Key 格式（JWT 格式）
        guard supabaseAnonKey.contains(".") && supabaseAnonKey.count > 50 else {
            fatalError("❌ Supabase API Key 格式无效")
        }
        
        print("✅ Supabase 配置验证通过")
    }
    
    // MARK: - Database Connection Methods
    
    /**
     * 测试数据库连接
     */
    func testDatabaseConnection() async -> Bool {
        do {
            print("🔄 开始测试数据库连接...")
            
            // 执行一个简单的查询来测试连接
            let response = try await client.database
                .from("users")
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ 数据库连接测试成功")
            print("📊 响应状态: \(response.status)")
            return true
            
        } catch {
            print("❌ 数据库连接测试失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /**
     * 测试认证服务连接
     */
    func testAuthConnection() async -> Bool {
        do {
            print("🔄 开始测试认证服务连接...")
            
            // 获取当前会话状态
            let session = try await client.auth.session
            print("✅ 认证服务连接成功")
            print("👤 当前会话: \(session != nil ? "已登录" : "未登录")")
            return true
            
        } catch {
            print("❌ 认证服务连接失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /**
     * 检查数据库表结构
     */
    func checkDatabaseTables() async -> [String] {
        do {
            print("🔄 检查数据库表结构...")
            
            // 这里我们尝试查询几个关键表来验证结构
            let tables = ["users", "expenses", "budgets", "categories"]
            var existingTables: [String] = []
            
            for table in tables {
                do {
                    let response = try await client.database
                        .from(table)
                        .select("*")
                        .limit(1)
                        .execute()
                    
                    existingTables.append(table)
                    print("✅ 表 '\(table)' 存在")
                } catch {
                    print("⚠️ 表 '\(table)' 不存在或无权限访问: \(error.localizedDescription)")
                }
            }
            
            return existingTables
            
        } catch {
            print("❌ 检查数据库表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /**
     * 执行健康检查
     */
    func performHealthCheck() async -> HealthCheckResult {
        print("🏥 开始 Supabase 健康检查...")
        
        var result = HealthCheckResult()
        
        // 1. 配置检查
        result.configurationValid = checkConfiguration()
        print("📋 配置检查: \(result.configurationValid ? "✅" : "❌")")
        
        // 2. 网络连通性检查
        result.networkReachable = await testConfiguration()
        print("🌐 网络连通性: \(result.networkReachable ? "✅" : "❌")")
        
        // 3. 数据库连接检查
        result.databaseConnected = await testDatabaseConnection()
        print("🗄️ 数据库连接: \(result.databaseConnected ? "✅" : "❌")")
        
        // 4. 认证服务检查
        result.authServiceConnected = await testAuthConnection()
        print("🔐 认证服务: \(result.authServiceConnected ? "✅" : "❌")")
        
        // 5. 表结构检查
        result.availableTables = await checkDatabaseTables()
        print("📊 可用表: \(result.availableTables)")
        
        // 6. 总体状态
        result.overallHealthy = result.configurationValid && 
                               result.networkReachable && 
                               result.databaseConnected && 
                               result.authServiceConnected
        
        print("🏥 健康检查完成: \(result.overallHealthy ? "✅ 健康" : "❌ 有问题")")
        
        return result
    }
    
    // MARK: - Public Methods
    
    /**
     * 获取 Supabase URL
     */
    func getSupabaseURL() -> String {
        return supabaseUrl
    }
    
    /**
     * 获取匿名 API Key
     */
    func getAnonKey() -> String {
        return supabaseAnonKey
    }
    
    /**
     * 检查配置状态
     */
    func checkConfiguration() -> Bool {
        return !supabaseUrl.isEmpty && !supabaseAnonKey.isEmpty
    }
    
    /**
     * 打印调试信息
     */
    func printDebugInfo() {
        print("🔍 SupabaseManager 调试信息:")
        print("📍 URL: \(supabaseUrl)")
        print("🔑 Key: \(String(supabaseAnonKey.prefix(20)))...")
        print("✅ 配置状态: \(checkConfiguration() ? "有效" : "无效")")
        print("🔌 客户端状态: \(_client != nil ? "已初始化" : "未初始化")")
    }
    
    /**
     * 准备就绪检查
     */
    func isReady() -> Bool {
        return checkConfiguration()
    }
    
    /**
     * 测试配置连接性
     */
    func testConfiguration() async -> Bool {
        // 简单的 URL 连通性测试
        guard let url = URL(string: supabaseUrl) else {
            print("❌ URL 格式错误")
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                let isReachable = httpResponse.statusCode < 500
                print(isReachable ? "✅ Supabase 服务可达" : "❌ Supabase 服务不可达")
                return isReachable
            }
        } catch {
            print("❌ 连接测试失败: \(error.localizedDescription)")
        }
        
        return false
    }
}

// MARK: - Health Check Result

struct HealthCheckResult {
    var configurationValid: Bool = false
    var networkReachable: Bool = false
    var databaseConnected: Bool = false
    var authServiceConnected: Bool = false
    var availableTables: [String] = []
    var overallHealthy: Bool = false
    
    func printSummary() {
        print("\n📊 Supabase 健康检查报告")
        print("================================")
        print("📋 配置验证: \(configurationValid ? "✅" : "❌")")
        print("🌐 网络连通: \(networkReachable ? "✅" : "❌")")
        print("🗄️ 数据库连接: \(databaseConnected ? "✅" : "❌")")
        print("🔐 认证服务: \(authServiceConnected ? "✅" : "❌")")
        print("📊 可用表数量: \(availableTables.count)")
        print("📋 可用表: \(availableTables.joined(separator: ", "))")
        print("🏥 总体状态: \(overallHealthy ? "✅ 健康" : "❌ 需要关注")")
        print("================================\n")
    }
} 