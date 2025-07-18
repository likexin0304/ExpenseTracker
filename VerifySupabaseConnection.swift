#!/usr/bin/env swift

import Foundation

/**
 * Supabase 连接验证器
 * 验证 ExpenseTracker 中配置的 Supabase 连接是否有效
 */
class SupabaseConnectionVerifier {
    
    // 从 Info.plist 中读取的实际配置
    static let supabaseURL = "https://nlrtjnvwgsaavtpfccxg.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5scnRqbnZ3Z3NhYXZ0cGZjY3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNzU3MDgsImV4cCI6MjA2NTY1MTcwOH0.5r2tzDOV1T1Lkz_Mtujq35VBBfo77SCh6H__rUSHQCo"
    
    static func verifyConnection() {
        print("🔍 验证 ExpenseTracker Supabase 连接配置")
        print(String(repeating: "=", count: 50))
        
        // 步骤 1: 配置验证
        print("\n1️⃣ 配置验证...")
        print("📍 URL: \(supabaseURL)")
        print("🔑 API Key: \(String(supabaseAnonKey.prefix(30)))...")
        
        guard let url = URL(string: supabaseURL) else {
            print("❌ URL 格式无效")
            return
        }
        
        print("✅ URL 格式正确")
        print("🏠 Host: \(url.host ?? "unknown")")
        print("📡 Scheme: \(url.scheme ?? "unknown")")
        
        // 步骤 2: 网络连通性测试
        print("\n2️⃣ 网络连通性测试...")
        testNetworkConnection(url: url)
        
        // 步骤 3: API 端点测试
        print("\n3️⃣ API 端点测试...")
        testAPIEndpoints(baseURL: url)
        
        // 步骤 4: 认证测试
        print("\n4️⃣ 认证配置测试...")
        testAuthConfiguration()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ Supabase 连接验证完成！")
        print("💡 您的 ExpenseTracker 应用已配置实际的 Supabase 连接")
        print("🚀 可以在应用中进行真实的数据库操作测试")
    }
    
    static func testNetworkConnection(url: URL) {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        print("🔄 测试网络连接到 \(url.host ?? "Supabase")...")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ 网络连接失败: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                success = true
                print("✅ 网络连接成功")
                print("📊 HTTP 状态码: \(httpResponse.statusCode)")
                
                if let data = data, data.count > 0 {
                    print("📦 响应数据大小: \(data.count) bytes")
                }
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        if success {
            print("🌐 Supabase 服务器可达")
        }
    }
    
    static func testAPIEndpoints(baseURL: URL) {
        let endpoints = [
            "/rest/v1/",
            "/auth/v1/",
            "/storage/v1/",
            "/realtime/v1/"
        ]
        
        print("🔄 测试 API 端点...")
        
        for endpoint in endpoints {
            if let endpointURL = URL(string: endpoint, relativeTo: baseURL) {
                print("📡 检查端点: \(endpoint)")
                testEndpoint(url: endpointURL, endpoint: endpoint)
            }
        }
    }
    
    static func testEndpoint(url: URL, endpoint: String) {
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                switch statusCode {
                case 200...299:
                    print("   ✅ \(endpoint): 正常 (\(statusCode))")
                case 400...499:
                    print("   ⚠️ \(endpoint): 客户端错误 (\(statusCode))")
                case 500...599:
                    print("   ❌ \(endpoint): 服务器错误 (\(statusCode))")
                default:
                    print("   ❓ \(endpoint): 未知状态 (\(statusCode))")
                }
            } else if let error = error {
                print("   ❌ \(endpoint): 连接错误 - \(error.localizedDescription)")
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
    }
    
    static func testAuthConfiguration() {
        print("🔄 验证认证配置...")
        
        // 验证 JWT Token 格式
        let parts = supabaseAnonKey.components(separatedBy: ".")
        if parts.count == 3 {
            print("✅ API Key 格式正确 (JWT)")
            
            // 尝试解码 JWT payload
            if let payloadData = Data(base64Encoded: parts[1] + "=="),
               let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                print("📋 JWT Payload 信息:")
                if let iss = payload["iss"] as? String {
                    print("   发行者: \(iss)")
                }
                if let ref = payload["ref"] as? String {
                    print("   项目引用: \(ref)")
                }
                if let role = payload["role"] as? String {
                    print("   角色: \(role)")
                }
                if let exp = payload["exp"] as? TimeInterval {
                    let expDate = Date(timeIntervalSince1970: exp)
                    print("   过期时间: \(expDate)")
                }
            }
        } else {
            print("❌ API Key 格式无效")
        }
    }
}

// 运行验证
print("🎯 ExpenseTracker Supabase 连接验证")
print("正在验证您的实际 Supabase 配置...")
print("")

SupabaseConnectionVerifier.verifyConnection()

print("\n🔍 验证结果说明:")
print("✅ 绿色 = 配置正确，功能正常")
print("⚠️ 黄色 = 配置正确，但可能需要进一步设置")
print("❌ 红色 = 存在问题，需要检查配置")
print("")
print("📱 下一步: 在 iOS 应用中测试实际的数据库操作") 