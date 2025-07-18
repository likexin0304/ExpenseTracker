import Foundation

/**
 * 数据库连接测试脚本
 * 直接在控制台中运行数据库连接测试
 */

// MARK: - 测试执行函数

/**
 * 执行数据库连接测试
 */
func testDatabaseConnection() async {
    print("\n🚀 开始数据库连接测试")
    print("================================")
    
    // 获取 SupabaseManager 实例
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
        let url = client.supabaseURL.absoluteString
        print("✅ 客户端初始化: 成功")
        print("   连接到: \(url)")
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
 * 执行完整健康检查
 */
func runFullHealthCheck() async {
    print("\n🏥 开始 Supabase 完整健康检查")
    print("================================")
    
    let supabaseManager = SupabaseManager.shared
    let healthResult = await supabaseManager.performHealthCheck()
    
    // 打印详细报告
    healthResult.printSummary()
}

/**
 * 测试特定功能
 */
func testSpecificFeature() async {
    print("\n🔬 测试特定 Supabase 功能")
    print("================================")
    
    let supabaseManager = SupabaseManager.shared
    
    // 测试简单查询
    print("📝 测试简单数据库查询...")
    do {
        let client = supabaseManager.client
        
        // 尝试执行一个非常简单的查询
        let response = try await client.database
            .from("users")
            .select("count")
            .execute()
        
        print("✅ 查询执行成功")
        print("   响应状态: \(response.status)")
        print("   数据长度: \(response.data.count) 字节")
        
    } catch {
        print("❌ 查询执行失败")
        print("   错误: \(error.localizedDescription)")
        
        // 尝试分析错误类型
        if error.localizedDescription.contains("relation") && error.localizedDescription.contains("does not exist") {
            print("💡 这表明 'users' 表不存在，这是正常的")
            print("   您需要在 Supabase 中创建数据库表")
        } else if error.localizedDescription.contains("permission") {
            print("💡 这可能是权限问题")
            print("   请检查 RLS (Row Level Security) 设置")
        }
    }
    
    print("================================\n")
} 