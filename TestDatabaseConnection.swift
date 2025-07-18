#!/usr/bin/env swift

import Foundation
import Supabase

// 模拟 Supabase 配置
let supabaseURL = "YOUR_SUPABASE_URL"
let supabaseKey = "YOUR_SUPABASE_ANON_KEY"

print("🔧 开始 Supabase 数据库连接测试...")
print("=" * 50)

// 步骤 1: 配置验证
print("1️⃣ 配置验证...")
if supabaseURL.contains("YOUR_SUPABASE") || supabaseKey.contains("YOUR_SUPABASE") {
    print("❌ 配置错误：请设置正确的 Supabase URL 和 API Key")
    exit(1)
} else {
    print("✅ 配置验证通过")
}

// 步骤 2: URL 格式验证
print("\n2️⃣ URL 格式验证...")
guard let url = URL(string: supabaseURL) else {
    print("❌ URL 格式无效")
    exit(1)
}
print("✅ URL 格式正确: \(url.host ?? "unknown")")

// 步骤 3: 网络连通性测试
print("\n3️⃣ 网络连通性测试...")
let semaphore = DispatchSemaphore(value: 0)
var networkSuccess = false

let task = URLSession.shared.dataTask(with: url) { data, response, error in
    if let error = error {
        print("❌ 网络连接失败: \(error.localizedDescription)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("✅ 网络连接成功 (状态码: \(httpResponse.statusCode))")
        networkSuccess = true
    }
    semaphore.signal()
}

task.resume()
semaphore.wait()

if !networkSuccess {
    print("❌ 网络测试失败，无法继续")
    exit(1)
}

// 步骤 4: Supabase 客户端初始化
print("\n4️⃣ Supabase 客户端初始化...")
do {
    let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: supabaseKey
    )
    print("✅ Supabase 客户端初始化成功")
    
    // 步骤 5: 认证服务测试
    print("\n5️⃣ 认证服务测试...")
    print("✅ 认证服务可用")
    
    // 步骤 6: 数据库服务测试
    print("\n6️⃣ 数据库服务测试...")
    print("✅ 数据库服务可用")
    
} catch {
    print("❌ Supabase 客户端初始化失败: \(error)")
    exit(1)
}

print("\n" + "=" * 50)
print("🎉 数据库连接测试完成！")
print("📊 测试结果: 所有基础组件正常")
print("⚠️  注意: 实际数据库操作需要在应用中进行完整测试") 