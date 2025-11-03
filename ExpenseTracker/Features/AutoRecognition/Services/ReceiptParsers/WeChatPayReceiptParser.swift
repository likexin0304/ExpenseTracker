import Foundation

/// 微信支付账单解析器
/// 专门针对微信支付账单进行优化，支持标准支付和退款账单
class WeChatPayReceiptParser: ReceiptParserProtocol {
    var name: String { return "微信支付解析器" }
    
    func canParse(_ text: String) -> Bool {
        let normalizedText = text.lowercased()
        return normalizedText.contains("微信") || 
               normalizedText.contains("wechat") ||
               normalizedText.contains("支付成功") ||
               normalizedText.contains("payment successful")
    }
    
    func parse(_ text: String) -> ParsedReceiptData {
        print("💚 使用微信支付专用解析器")
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var result = ParsedReceiptData()
        
        // 检测是否是退款账单
        let isRefund = detectRefund(from: text)
        
        // 1. 解析金额（最重要）
        result.amount = parseAmount(from: lines)
        
        // 2. 解析商户名称（优先级策略）
        result.merchantName = parseMerchant(from: lines)
        
        // 3. 解析日期时间（退款账单使用退款时间）
        result.dateTime = parseDateTime(from: lines, isRefund: isRefund)
        
        // 4. 解析支付方式
        result.paymentMethod = parsePaymentMethod(from: lines)
        
        // 5. 解析商品/服务
        result.products = parseProducts(from: lines)
        
        // 6. 智能推断类别
        result.category = inferCategory(merchantName: result.merchantName, products: result.products)
        
        // 7. 计算置信度
        result.confidence = calculateConfidence(result)
        
        printResult(result, isRefund: isRefund)
        
        return result
    }
    
    // MARK: - 退款检测
    
    /// 检测是否是退款账单
    private func detectRefund(from text: String) -> Bool {
        let refundKeywords = [
            "Refund Records",
            "Fully refunded",
            "退款",
            "已退款",
            "Refund"
        ]
        
        let normalizedText = text.lowercased()
        return refundKeywords.contains { normalizedText.contains($0.lowercased()) }
    }
    
    // MARK: - 金额解析
    
    /// 解析微信支付金额（针对微信支付特点优化）
    private func parseAmount(from lines: [String]) -> Double? {
        print("💰 解析微信支付金额...")
        
        // 微信支付金额通常在顶部1-3行，格式："-9.90" 或 "-100.00"
        for (index, line) in lines.prefix(5).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 优先匹配负号开头（微信支付最常见格式）
            if trimmed.hasPrefix("-") {
                if let amount = extractAmount(trimmed) {
                    print("✅ 微信支付金额: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
            
            // 匹配¥符号开头
            if trimmed.hasPrefix("¥") {
                if let amount = extractAmount(trimmed) {
                    print("✅ 微信支付金额: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
            
            // 匹配纯数字金额（如 9.90 或 100.00）
            if let amount = extractAmount(trimmed) {
                // 确保是合理的金额范围（0.01 - 999999.99）
                if amount > 0.01 && amount < 1000000 {
                    print("✅ 微信支付金额: \(amount) (第\(index + 1)行)")
                    return amount
                }
            }
        }
        
        // 策略2: 查找包含"支付金额"、"实付"等关键词的行
        let amountKeywords = ["支付金额", "实付", "总计", "合计", "应付"]
        for (index, line) in lines.enumerated() {
            for keyword in amountKeywords {
                if line.contains(keyword) {
                    if let amount = extractAmount(line) {
                        print("✅ 微信支付金额（关键词）: \(amount)")
                        return amount
                    }
                    if index + 1 < lines.count {
                        if let amount = extractAmount(lines[index + 1]) {
                            print("✅ 微信支付金额（关键词下一行）: \(amount)")
                            return amount
                        }
                    }
                }
            }
        }
        
        print("⚠️ 未找到金额")
        return nil
    }
    
    /// 从文本行中提取金额数值
    private func extractAmount(_ text: String) -> Double? {
        var cleaned = text
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
    
    // MARK: - 商户名称解析（优先级策略）
    
    /// 解析微信支付商户名称（优先级：门店名 > 品牌名 > 公司名）
    private func parseMerchant(from lines: [String]) -> String? {
        print("🏪 解析微信支付商户名称...")
        
        // 排除的关键词（这些行不是商家名）
        let excludePatterns = [
            "支付成功", "交易成功", "Payment", "successful", "Successful",
            "Status", "Time", "Products", "Method", "Transaction", "Order",
            "当前", "全部", "交易", "详情", "收款方", "付款方", "备注",
            "转账", "红包", "充值", "提现", "Refund Records", "Fully refunded"
        ]
        
        var candidates: [(name: String, priority: Int, index: Int)] = []
        
        // 查找前15行中的商户名称
        for (index, line) in lines.prefix(15).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过金额行
            if extractAmount(trimmed) != nil {
                continue
            }
            
            // 跳过太短的行（< 2个字符）
            if trimmed.count < 2 {
                continue
            }
            
            // 跳过只包含符号的行
            if trimmed.allSatisfy({ !$0.isLetter && !$0.isNumber && !$0.isCJK }) {
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
            
            if cleaned.count < 2 {
                continue
            }
            
            // 优先级1：门店名（包含"-"和"店"的短名称，如"RSE-上海中山龙之梦店"）
            if cleaned.contains("-") && cleaned.contains("店") && cleaned.count <= 30 {
                candidates.append((cleaned, 1, index))
                print("  ✅ 找到门店名候选: \(cleaned) (优先级1)")
                continue
            }
            
            // 优先级2：品牌名（短名称，2-30字符，如"luckin coffee"、"滴滴出行"）
            if cleaned.count >= 2 && cleaned.count <= 30 {
                // 检查是否包含常见商家关键词
                let merchantKeywords = [
                    "餐厅", "餐饮", "咖啡", "科技", "有限公司", "集团",
                    "McDonald", "luckin", "coffee", "店", "商", "行", "RSE",
                    "滴滴", "京东", "电器"
                ]
                
                let hasMerchantKeyword = merchantKeywords.contains { cleaned.contains($0) }
                
                // 如果包含商家关键词，或者是前5行中的非公司名，优先考虑
                if hasMerchantKeyword || (index < 5 && !cleaned.contains("有限公司")) {
                    // 如果是公司全称（包含"有限公司"且长度>20），降级优先级
                    if cleaned.contains("有限公司") && cleaned.count > 20 {
                        candidates.append((cleaned, 3, index))
                        print("  ⚠️ 找到公司名候选: \(cleaned) (优先级3)")
                    } else {
                        candidates.append((cleaned, 2, index))
                        print("  ✅ 找到品牌名候选: \(cleaned) (优先级2)")
                    }
                }
            }
            
            // 优先级3：公司名（包含"有限公司"的长名称）
            if cleaned.contains("有限公司") && cleaned.count > 10 {
                candidates.append((cleaned, 3, index))
                print("  ⚠️ 找到公司名候选: \(cleaned) (优先级3)")
            }
        }
        
        // 按优先级和位置排序
        candidates.sort { (first, second) in
            if first.priority != second.priority {
                return first.priority < second.priority
            }
            return first.index < second.index
        }
        
        if let best = candidates.first {
            print("✅ 选择商户名称: \(best.name) (优先级\(best.priority), 第\(best.index + 1)行)")
            return best.name
        }
        
        print("⚠️ 未找到商户名称")
        return nil
    }
    
    // MARK: - 日期时间解析
    
    /// 解析微信支付日期时间（退款账单使用退款时间）
    private func parseDateTime(from lines: [String], isRefund: Bool) -> Date? {
        print("📅 解析微信支付日期时间...")
        
        if isRefund {
            // 退款账单：查找"Refund Records"后的时间
            print("  ⚠️ 检测到退款账单，查找退款时间")
            for (index, line) in lines.enumerated() {
                if line.contains("Refund Records") || line.contains("退款") {
                    // 检查当前行或下一行
                    if let date = parseDateString(line) {
                        print("✅ 找到退款时间: \(line)")
                        return date
                    }
                    if index + 1 < lines.count {
                        if let date = parseDateString(lines[index + 1]) {
                            print("✅ 找到退款时间（下一行）: \(lines[index + 1])")
                            return date
                        }
                    }
                }
            }
        }
        
        // 策略1: 查找时间相关标签后的内容
        let timeKeywords = ["支付时间", "交易时间", "付款时间", "Payment Time", "Time"]
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
    
    /// 解析日期字符串
    /// 支持多种日期格式：YYYY/MM/DD HH:mm:ss, YYYY-MM-DD HH:mm:ss, YYYY/MM/DD HH:mm, MM/dd HH:mm等
    private func parseDateString(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // ✅ 格式1: "yyyy/MM/dd HH:mm:ss" (如 "2025/10/31 14:01:44")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // ✅ 格式2: "yyyy-MM-dd HH:mm:ss" (如 "2025-10-31 14:01:44")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // ✅ 格式3: "yyyy/MM/dd HH:mm" (没有秒)
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // ✅ 格式4: "yyyy-MM-dd HH:mm" (没有秒)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // ✅ 格式5: "MM/dd HH:mm" (没有年份，使用当前年份)
        formatter.dateFormat = "MM/dd HH:mm"
        if let date = formatter.date(from: text) {
            // 获取当前年份
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            // 创建完整的日期
            var components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
            components.year = currentYear
            return calendar.date(from: components)
        }
        
        // ✅ 格式6: "MM-dd HH:mm" (没有年份，使用当前年份)
        formatter.dateFormat = "MM-dd HH:mm"
        if let date = formatter.date(from: text) {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            var components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
            components.year = currentYear
            return calendar.date(from: components)
        }
        
        return nil
    }
    
    // MARK: - 支付方式解析
    
    /// 解析支付方式（提取银行名 + 信用卡类型）
    private func parsePaymentMethod(from lines: [String]) -> String? {
        print("💳 解析微信支付支付方式...")
        
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
        
        print("⚠️ 未找到支付方式，使用默认")
        return "其他"
    }
    
    /// 从文本行中提取支付方式
    /// 支持银行名称识别（CMB、ICBC等），区分信用卡和银行卡
    private func extractPaymentMethodFromLine(_ line: String) -> String? {
        let lowercasedLine = line.lowercased()
        
        // 微信支付
        if line.contains("微信") || lowercasedLine.contains("wechat") {
            return "微信"
        }
        // 支付宝
        if line.contains("支付宝") || lowercasedLine.contains("alipay") {
            return "支付宝"
        }
        
        // ✅ 信用卡识别（优先于银行卡）
        // 匹配: "CMB Credit Card(1578)", "ICBC Credit Card(0200)", "工商银行信用卡"等
        let creditCardKeywords = ["信用卡", "credit card", "credit"]
        let hasCreditCardKeyword = creditCardKeywords.contains { lowercasedLine.contains($0) }
        
        // ✅ 支持银行名称识别
        let bankNames: [String: String] = [
            "icbc": "工商银行",
            "工商银行": "工商银行",
            "cmb": "招商银行",
            "招商银行": "招商银行",
            "ccb": "建设银行",
            "建设银行": "建设银行",
            "abc": "农业银行",
            "农业银行": "农业银行",
            "boc": "中国银行",
            "中国银行": "中国银行"
        ]
        
        var detectedBank: String? = nil
        for (keyword, bankName) in bankNames {
            if lowercasedLine.contains(keyword) {
                detectedBank = bankName
                break
            }
        }
        
        // 如果包含信用卡关键词，返回"银行名+信用卡"或"信用卡"
        if hasCreditCardKeyword {
            if let bank = detectedBank {
                return "\(bank)信用卡"
            }
            return "信用卡"
        }
        
        // 借记卡
        if line.contains("借记卡") || lowercasedLine.contains("debit card") || 
           lowercasedLine.contains("debit") || line.contains("储蓄卡") {
            if let bank = detectedBank {
                return "\(bank)借记卡"
            }
            return "银行卡"
        }
        
        // 银行卡（通用）
        if line.contains("银行卡") || lowercasedLine.contains("bank card") {
            if let bank = detectedBank {
                return "\(bank)银行卡"
            }
            return "银行卡"
        }
        
        // 现金
        if line.contains("现金") || lowercasedLine.contains("cash") {
            return "现金"
        }
        
        return nil
    }
    
    // MARK: - 商品/服务解析
    
    /// 解析商品/服务
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
    
    // MARK: - 类别推断
    
    /// 智能推断类别
    private func inferCategory(merchantName: String?, products: String?) -> String {
        print("🏷️ 推断类别...")
        
        let text = "\(merchantName ?? "") \(products ?? "")".lowercased()
        
        // 餐饮
        let foodKeywords = [
            "麦当劳", "肯德基", "星巴克", "瑞幸", "luckin", "咖啡", "coffee",
            "餐", "食品", "饮", "茶", "奶茶", "快餐", "美食", "外卖",
            "必胜客", "汉堡", "披萨", "pizza", "restaurant", "cafe",
            "RSE", "江边城外", "餐饮有限公司", "餐饮"
        ]
        
        // 交通
        let transportKeywords = [
            "滴滴", "didi", "打车", "出行", "taxi", "uber",
            "地铁", "公交", "停车", "parking", "加油", "油站"
        ]
        
        // 购物
        let shoppingKeywords = [
            "京东", "电器", "商场", "超市", "便利", "711", "全家", "罗森",
            "淘宝", "天猫", "拼多多", "商城", "mall"
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
    
    // MARK: - 置信度计算
    
    /// 计算解析置信度
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
        if let method = data.paymentMethod, !method.isEmpty && method != "其他" {
            score += 10
        }
        
        // 类别 (5分)
        maxScore += 5
        if !data.category.isEmpty && data.category != "其他" {
            score += 5
        }
        
        let confidence = maxScore > 0 ? score / maxScore : 0.0
        print("📊 置信度: \(String(format: "%.2f", confidence * 100))% (\(Int(score))/\(Int(maxScore)))")
        return confidence
    }
    
    // MARK: - 结果打印
    
    /// 打印解析结果
    private func printResult(_ data: ParsedReceiptData, isRefund: Bool) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 微信支付解析结果\(isRefund ? "（退款）" : "") :")
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

// MARK: - Character Extension

extension Character {
    /// 是否是中文字符
    var isCJK: Bool {
        return "\u{4E00}" <= self && self <= "\u{9FFF}"
    }
}

