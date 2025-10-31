import Foundation

/// ExpenseCorrections 中文映射自测工具
/// 用于验证中文到英文的字段映射功能
class ExpenseCorrectionsMapTest {
    
    /// 测试分类映射
    static func testCategoryMapping() {
        print("\n🧪 ===== 测试分类映射 =====")
        
        let testCases: [(input: String, expected: String)] = [
            // 中文测试
            ("其他", "other"),
            ("餐饮", "food"),
            ("交通", "transport"),
            ("娱乐", "entertainment"),
            ("购物", "shopping"),
            ("服装", "shopping"),
            ("账单", "bills"),
            ("医疗", "healthcare"),
            ("教育", "education"),
            ("旅行", "travel"),
            // 英文测试（应该保持不变）
            ("food", "food"),
            ("transport", "transport"),
            ("other", "other"),
            // 未知分类（应该映射为other）
            ("未知分类", "other")
        ]
        
        var passCount = 0
        var failCount = 0
        
        for (input, expected) in testCases {
            let corrections = ExpenseCorrections(
                amount: 100.0,
                category: ExpenseCategory(rawValue: input),
                description: "测试",
                paymentMethod: PaymentMethod(rawValue: "cash")
            )
            
            let actual = corrections.category?.rawValue ?? "nil"
            if actual == expected {
                print("✅ \(input) → \(actual)")
                passCount += 1
            } else {
                print("❌ \(input) → \(actual) (期望: \(expected))")
                failCount += 1
            }
        }
        
        print("\n📊 分类映射测试结果: ✅ \(passCount)个通过, ❌ \(failCount)个失败")
    }
    
    /// 测试支付方式映射
    static func testPaymentMethodMapping() {
        print("\n🧪 ===== 测试支付方式映射 =====")
        
        let testCases: [(input: String, expected: String)] = [
            // 中文测试
            ("其他", "other"),
            ("现金", "cash"),
            ("银行卡", "card"),
            ("信用卡", "card"),
            ("借记卡", "card"),
            ("支付宝", "online"),
            ("微信支付", "online"),
            ("微信", "online"),
            // 英文测试（应该保持不变）
            ("cash", "cash"),
            ("card", "card"),
            ("online", "online"),
            ("other", "other"),
            // 未知支付方式（应该映射为other）
            ("未知支付", "other")
        ]
        
        var passCount = 0
        var failCount = 0
        
        for (input, expected) in testCases {
            let corrections = ExpenseCorrections(
                amount: 100.0,
                category: ExpenseCategory(rawValue: "food"),
                description: "测试",
                paymentMethod: PaymentMethod(rawValue: input)
            )
            
            let actual = corrections.paymentMethod?.rawValue ?? "nil"
            if actual == expected {
                print("✅ \(input) → \(actual)")
                passCount += 1
            } else {
                print("❌ \(input) → \(actual) (期望: \(expected))")
                failCount += 1
            }
        }
        
        print("\n📊 支付方式映射测试结果: ✅ \(passCount)个通过, ❌ \(failCount)个失败")
    }
    
    /// 测试完整的支出创建场景
    static func testCompleteScenario() {
        print("\n🧪 ===== 测试完整场景 =====")
        
        // 场景1: 用户使用中文输入
        print("\n📝 场景1: 用户选择中文选项")
        let corrections1 = ExpenseCorrections(
            amount: 100.0,
            category: ExpenseCategory(rawValue: "交通"),
            description: "过路费",
            date: Date(),
            location: "高速公路",
            paymentMethod: PaymentMethod(rawValue: "支付宝"),
            tags: ["出行", "工作"]
        )
        
        print("   输入: 分类=交通, 支付方式=支付宝")
        print("   输出: category=\(corrections1.category?.rawValue ?? "nil"), paymentMethod=\(corrections1.paymentMethod?.rawValue ?? "nil")")
        
        let scenario1Pass = corrections1.category?.rawValue == "transport" && corrections1.paymentMethod?.rawValue == "online"
        print(scenario1Pass ? "   ✅ 场景1通过" : "   ❌ 场景1失败")
        
        // 场景2: 用户使用英文输入
        print("\n📝 场景2: 用户选择英文选项")
        let corrections2 = ExpenseCorrections(
            amount: 50.0,
            category: ExpenseCategory(rawValue: "food"),
            description: "午餐",
            paymentMethod: PaymentMethod(rawValue: "cash")
        )
        
        print("   输入: 分类=food, 支付方式=cash")
        print("   输出: category=\(corrections2.category?.rawValue ?? "nil"), paymentMethod=\(corrections2.paymentMethod?.rawValue ?? "nil")")
        
        let scenario2Pass = corrections2.category?.rawValue == "food" && corrections2.paymentMethod?.rawValue == "cash"
        print(scenario2Pass ? "   ✅ 场景2通过" : "   ❌ 场景2失败")
        
        // 场景3: 用户的实际报错场景
        print("\n📝 场景3: 用户报错场景重现")
        let corrections3 = ExpenseCorrections(
            amount: 100.0,
            category: ExpenseCategory(rawValue: "其他"),
            description: "我",
            date: Date(),
            paymentMethod: PaymentMethod(rawValue: "其他")
        )
        
        print("   输入: 分类=其他, 支付方式=其他")
        print("   输出: category=\(corrections3.category?.rawValue ?? "nil"), paymentMethod=\(corrections3.paymentMethod?.rawValue ?? "nil")")
        
        let scenario3Pass = corrections3.category?.rawValue == "other" && corrections3.paymentMethod?.rawValue == "other"
        print(scenario3Pass ? "   ✅ 场景3通过 (不再发送中文，后端应该接受)" : "   ❌ 场景3失败")
        
        print("\n📊 完整场景测试结果: \(scenario1Pass && scenario2Pass && scenario3Pass ? "✅ 全部通过" : "❌ 存在失败")")
    }
    
    /// 运行所有测试
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 ExpenseCorrections 中文映射功能自测")
        print(String(repeating: "=", count: 60))
        
        testCategoryMapping()
        testPaymentMethodMapping()
        testCompleteScenario()
        
        print("\n" + String(repeating: "=", count: 60))
        print("✅ 所有测试完成")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - 使用方法
/*
 在应用启动时或需要测试时调用:
 
 ExpenseCorrectionsMapTest.runAllTests()
 
 或在ExpenseTrackerApp.swift的init方法中添加:
 
 #if DEBUG
 ExpenseCorrectionsMapTest.runAllTests()
 #endif
 */

