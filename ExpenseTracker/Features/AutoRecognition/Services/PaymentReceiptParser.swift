import Foundation
import UIKit

/**
 * 支付凭证解析器
 * 专门针对支付App交易详情页的文本解析
 * 
 * 特点：
 * - 识别结构化的交易信息（带英文标签）
 * - 高准确度提取金额、商家、日期、支付方式
 * - 智能类别推断
 */
class PaymentReceiptParser {
    
    // MARK: - Singleton
    
    static let shared = PaymentReceiptParser()
    
    private init() {
        print("💳 PaymentReceiptParser初始化")
    }
    
    // MARK: - Public Methods
    
    /**
     * 解析支付凭证文本
     * - Parameter text: OCR识别的原始文本
     * - Returns: 解析后的支出数据
     */
    func parsePaymentReceipt(_ text: String) -> ParsedReceiptData {
        print("💳 开始解析支付凭证...")
        print("📄 原始文本长度: \(text.count)字符")
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        print("📝 有效行数: \(lines.count)")
        
        var result = ParsedReceiptData()
        
        // 1. 解析金额（最重要）
        result.amount = parseAmount(from: lines)
        
        // 2. 解析商家名称
        result.merchantName = parseMerchantName(from: lines)
        
        // 3. 解析日期时间
        result.dateTime = parseDateTime(from: lines)
        
        // 4. 解析支付方式
        result.paymentMethod = parsePaymentMethod(from: lines)
        
        // 5. 解析商品/服务
        result.products = parseProducts(from: lines)
        
        // 6. 智能推断类别
        result.category = inferCategory(
            merchantName: result.merchantName,
            products: result.products
        )
        
        // 7. 计算置信度
        result.confidence = calculateConfidence(result)
        
        printResult(result)
        
        return result
    }
    
    // MARK: - Private Parsing Methods
    
    /**
     * 解析金额
     * 基于实际账单优化：
     * - 麦当劳: "-7.50" (负号开头)
     * - 瑞幸咖啡: "-11.90"
     * - RSE餐厅: "-236.40"
     * - 滴滴: "¥7.50" 或 纯数字
     */
    private func parseAmount(from lines: [String]) -> Double? {
        print("💰 解析金额...")
        
        // 策略1: 查找独立的金额行（通常在前3行）
        // 中文支付App习惯在最顶部显示大号金额
        for (index, line) in lines.prefix(5).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 优先匹配负号开头的金额（最常见）
            if trimmed.hasPrefix("-") {
                if let amount = extractAmountFromLine(trimmed) {
                    print("✅ 找到金额（负号）: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
            
            // 匹配¥符号开头
            if trimmed.hasPrefix("¥") {
                if let amount = extractAmountFromLine(trimmed) {
                    print("✅ 找到金额（¥符号）: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
            
            // 匹配纯数字金额（如 7.50 或 236.40）
            if let amount = extractAmountFromLine(trimmed) {
                // 确保是合理的金额范围（0.01 - 999999.99）
                if amount > 0.01 && amount < 1000000 {
                    print("✅ 找到金额（纯数字）: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
        }
        
        // 策略2: 查找包含"支付金额"、"实付"等关键词的行
        let amountKeywords = ["支付金额", "实付", "总计", "合计", "应付"]
        for (index, line) in lines.enumerated() {
            for keyword in amountKeywords {
                if line.contains(keyword) {
                    // 检查当前行或下一行
                    if let amount = extractAmountFromLine(line) {
                        print("✅ 找到金额（关键词）: \(amount)")
                        return amount
                    }
                    if index + 1 < lines.count {
                        if let amount = extractAmountFromLine(lines[index + 1]) {
                            print("✅ 找到金额（关键词下一行）: \(amount)")
                            return amount
                        }
                    }
                }
            }
        }
        
        print("⚠️ 未找到金额")
        return nil
    }
    
    /**
     * 从文本行中提取金额数值
     */
    private func extractAmountFromLine(_ line: String) -> Double? {
        // 清理文本
        var cleaned = line
        cleaned = cleaned.replacingOccurrences(of: "¥", with: "")
        cleaned = cleaned.replacingOccurrences(of: "RMB", with: "")
        cleaned = cleaned.replacingOccurrences(of: "元", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "") // 移除千位分隔符
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        // 移除负号（如果有）
        if cleaned.hasPrefix("-") {
            cleaned = String(cleaned.dropFirst())
        }
        
        // 尝试匹配纯数字格式: 123.45 或 123
        let pattern = "^\\d+(\\.\\d{1,2})?$"
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil {
            return Double(cleaned)
        }
        
        return nil
    }
    
    /**
     * 解析商家名称
     * 基于实际账单优化：
     * - 麦当劳: 第2-3行，中英文混合 "McDonald's麦当劳"
     * - 瑞幸咖啡: 第2行 "luckin coffee瑞幸咖啡"
     * - RSE餐厅: "RSE餐饮集团"
     * - 滴滴: "北京小桔科技有限公司" 或 "滴滴出行"
     */
    private func parseMerchantName(from lines: [String]) -> String? {
        print("🏪 解析商家名称...")
        
        // 排除的关键词（这些行不是商家名）
        let excludePatterns = [
            "支付成功", "交易成功", "Payment", "successful", "Successful",
            "Status", "Time", "Products", "Method", "Transaction", "Order",
            "当前", "全部", "交易", "详情", "收款方", "付款方", "备注",
            "转账", "红包", "充值", "提现"
        ]
        
        // 查找前15行中的商家名称（中文账单信息较多，需要看更多行）
        for (index, line) in lines.prefix(15).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过金额行
            if extractAmountFromLine(trimmed) != nil {
                continue
            }
            
            // 跳过太短的行（< 2个字符）
            if trimmed.count < 2 {
                continue
            }
            
            // 跳过只包含符号的行
            if trimmed.allSatisfy({ !$0.isLetter && !$0.isNumber }) {
                continue
            }
            
            // 跳过纯数字行
            if trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) {
                continue
            }
            
            // 跳过包含排除关键词的行
            var isExcluded = false
            for pattern in excludePatterns {
                if trimmed.contains(pattern) {
                    isExcluded = true
                    break
                }
            }
            
            if isExcluded {
                continue
            }
            
            // 清理特殊字符（保留中英文、数字、常见符号）
            let cleaned = trimmed.replacingOccurrences(
                of: "[^\\u4e00-\\u9fa5a-zA-Z0-9\\-() ]",
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
            
            // 商家名称通常2-30个字符
            if cleaned.count >= 2 && cleaned.count <= 30 {
                // 优先选择包含常见商家关键词的行
                let merchantKeywords = [
                    "餐厅", "餐饮", "咖啡", "科技", "有限公司", "集团",
                    "McDonald", "luckin", "coffee", "店", "商", "行"
                ]
                
                let hasMerchantKeyword = merchantKeywords.contains { cleaned.contains($0) }
                
                if hasMerchantKeyword || index >= 1 {
                    // 如果包含商家关键词，或者已经跳过了第一行（金额行），就采用
                    print("✅ 找到商家: \(cleaned) (第\(index + 1)行)")
                    return cleaned
                }
            }
        }
        
        print("⚠️ 未找到商家名称")
        return nil
    }
    
    /**
     * 解析日期时间
     * 基于实际账单优化：
     * - 支付宝/微信格式: "2025-10-27 19:41" 或 "10-27 19:41"
     * - 有些在"支付时间"、"交易时间"标签后
     */
    private func parseDateTime(from lines: [String]) -> Date? {
        print("📅 解析日期时间...")
        
        // 策略1: 查找时间相关标签后的内容
        let timeKeywords = ["支付时间", "交易时间", "付款时间", "Time", "时间"]
        for (index, line) in lines.enumerated() {
            for keyword in timeKeywords {
                if line.contains(keyword) {
                    // 检查当前行（可能在同一行）
                    if let date = parseDateString(line) {
                        print("✅ 找到日期（标签行）: \(line)")
                        return date
                    }
                    // 检查下一行
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1]
                        if let date = parseDateString(nextLine) {
                            print("✅ 找到日期（标签下一行）: \(nextLine)")
                            return date
                        }
                    }
                }
            }
        }
        
        // 策略2: 直接扫描所有行，匹配日期格式
        for line in lines {
            if let date = parseDateString(line) {
                print("✅ 找到日期（直接匹配）: \(line)")
                return date
            }
        }
        
        print("⚠️ 未找到日期，使用当前时间")
        return Date()
    }
    
    /**
     * 解析日期字符串
     */
    private func parseDateString(_ text: String) -> Date? {
        // 格式: "2025/10/27 19:41:36"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter.date(from: text) {
            return date
        }
        
        // 尝试其他格式
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }
    
    /**
     * 解析支付方式
     * 基于实际账单优化：
     * - 支付宝/微信支付最常见
     * - 通常在"支付方式"标签后，或文本中包含关键词
     */
    private func parsePaymentMethod(from lines: [String]) -> String? {
        print("💳 解析支付方式...")
        
        // 策略1: 查找"支付方式"标签后的内容
        let methodKeywords = ["支付方式", "付款方式", "Payment Method"]
        for (index, line) in lines.enumerated() {
            for keyword in methodKeywords {
                if line.contains(keyword) {
                    // 检查当前行（可能在同一行）
                    let method = extractPaymentMethodFromLine(line)
                    if let method = method {
                        print("✅ 找到支付方式（标签行）: \(method)")
                        return method
                    }
                    // 检查下一行
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1]
                        if let method = extractPaymentMethodFromLine(nextLine) {
                            print("✅ 找到支付方式（标签下一行）: \(method)")
                            return method
                        }
                    }
                }
            }
        }
        
        // 策略2: 直接扫描所有行，匹配支付方式关键词
        for line in lines {
            if let method = extractPaymentMethodFromLine(line) {
                print("✅ 找到支付方式（直接匹配）: \(method)")
                return method
            }
        }
        
        // 策略3: 根据商家推断（如果是小桔科技，很可能是微信或支付宝）
        print("⚠️ 未找到支付方式，使用默认")
        return "其他"
    }
    
    /**
     * 从文本行中提取支付方式
     */
    private func extractPaymentMethodFromLine(_ line: String) -> String? {
        // 微信支付
        if line.contains("微信") || line.contains("WeChat") || line.contains("wechat") {
            return "微信"
        }
        // 支付宝
        if line.contains("支付宝") || line.contains("Alipay") || line.contains("alipay") {
            return "支付宝"
        }
        // 信用卡
        if line.contains("信用卡") || line.contains("Credit Card") || line.contains("Credit") {
            return "银行卡"
        }
        // 借记卡
        if line.contains("借记卡") || line.contains("Debit Card") || line.contains("Debit") || line.contains("储蓄卡") {
            return "银行卡"
        }
        // 银行卡（通用）
        if line.contains("银行卡") || line.contains("Bank Card") {
            return "银行卡"
        }
        // 现金
        if line.contains("现金") || line.contains("Cash") {
            return "现金"
        }
        
        return nil
    }
    
    
    /**
     * 解析商品/服务
     * 模式：
     * 1. "Products" 后面的行
     * 2. 可能包含具体商品名或服务描述
     */
    private func parseProducts(from lines: [String]) -> String? {
        print("📦 解析商品/服务...")
        
        for (index, line) in lines.enumerated() {
            if line.contains("Products") || line.contains("商品") {
                // 检查下一行
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    // 排除商家信息（太长的行可能是商家全称）
                    if nextLine.count < 50 && !nextLine.contains("有限公司") {
                        print("✅ 找到商品: \(nextLine)")
                        return nextLine
                    }
                }
            }
        }
        
        print("⚠️ 未找到商品信息")
        return nil
    }
    
    /**
     * 智能推断类别
     * 基于商家名称和商品信息
     */
    private func inferCategory(merchantName: String?, products: String?) -> String {
        print("🏷️ 推断类别...")
        
        let text = "\(merchantName ?? "") \(products ?? "")".lowercased()
        
        // 餐饮
        let foodKeywords = [
            "麦当劳", "肯德基", "星巴克", "瑞幸", "luckin", "咖啡", "coffee",
            "餐", "食品", "饮", "茶", "奶茶", "快餐", "美食", "外卖",
            "必胜客", "汉堡", "披萨", "pizza", "restaurant", "cafe"
        ]
        
        // 交通
        let transportKeywords = [
            "滴滴", "didi", "打车", "出行", "taxi", "uber",
            "地铁", "公交", "停车", "parking", "加油", "油站"
        ]
        
        // 购物
        let shoppingKeywords = [
            "商场", "超市", "便利", "711", "全家", "罗森",
            "淘宝", "京东", "天猫", "拼多多", "商城", "mall"
        ]
        
        // 娱乐
        let entertainmentKeywords = [
            "影院", "电影", "ktv", "游戏", "健身", "spa"
        ]
        
        // 检查每个类别
        for keyword in foodKeywords {
            if text.contains(keyword) {
                print("✅ 推断类别: 餐饮 (匹配: \(keyword))")
                return "餐饮"
            }
        }
        
        for keyword in transportKeywords {
            if text.contains(keyword) {
                print("✅ 推断类别: 交通 (匹配: \(keyword))")
                return "交通"
            }
        }
        
        for keyword in shoppingKeywords {
            if text.contains(keyword) {
                print("✅ 推断类别: 购物 (匹配: \(keyword))")
                return "购物"
            }
        }
        
        for keyword in entertainmentKeywords {
            if text.contains(keyword) {
                print("✅ 推断类别: 娱乐 (匹配: \(keyword))")
                return "娱乐"
            }
        }
        
        print("⚠️ 无法推断类别，使用默认: 其他")
        return "其他"
    }
    
    /**
     * 计算解析置信度
     */
    private func calculateConfidence(_ data: ParsedReceiptData) -> Double {
        var score = 0.0
        var maxScore = 0.0
        
        // 金额 (40分)
        maxScore += 40
        if data.amount != nil && data.amount! > 0 {
            score += 40
        } else if data.amount != nil {
            score += 20 // 金额为0或负数，部分分数
        }
        
        // 商家 (30分)
        maxScore += 30
        if let merchant = data.merchantName, !merchant.isEmpty {
            score += 30
        }
        
        // 日期 (15分)
        maxScore += 15
        if data.dateTime != nil {
            score += 15
        }
        
        // 支付方式 (10分)
        maxScore += 10
        if let method = data.paymentMethod, !method.isEmpty {
            score += 10
        }
        
        // 类别 (5分)
        maxScore += 5
        if !data.category.isEmpty && data.category != "其他" {
            score += 5
        }
        
        let confidence = maxScore > 0 ? score / maxScore : 0.0
        print("📊 置信度: \(String(format: "%.2f", confidence * 100))% (\(score)/\(maxScore))")
        return confidence
    }
    
    /**
     * 打印解析结果
     */
    private func printResult(_ data: ParsedReceiptData) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 解析结果:")
        print("  💰 金额: \(data.amount.map { String(format: "%.2f", $0) } ?? "未识别")")
        print("  🏪 商家: \(data.merchantName ?? "未识别")")
        print("  📅 日期: \(data.dateTime.map { formatDate($0) } ?? "未识别")")
        print("  💳 支付: \(data.paymentMethod ?? "未识别")")
        print("  📦 商品: \(data.products ?? "未识别")")
        print("  🏷️ 类别: \(data.category)")
        print("  ⭐ 置信度: \(String(format: "%.1f%%", data.confidence * 100))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

/**
 * 解析后的支付凭证数据
 */
struct ParsedReceiptData {
    var amount: Double?
    var merchantName: String?
    var dateTime: Date?
    var paymentMethod: String?
    var products: String?
    var category: String = "其他"
    var confidence: Double = 0.0
    
    /// 是否包含足够信息（至少有金额和商家）
    var isValid: Bool {
        return amount != nil && amount! > 0 && merchantName != nil
    }
}

