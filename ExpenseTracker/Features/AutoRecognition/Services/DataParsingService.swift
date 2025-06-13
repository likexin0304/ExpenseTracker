import Foundation
import Combine

/**
 * 数据解析服务
 * 负责从OCR结果中提取和解析账单信息
 */
class DataParsingService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否正在解析
    @Published var isParsing: Bool = false
    
    /// 解析进度 (0.0 - 1.0)
    @Published var parsingProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    /// 解析队列
    private let parsingQueue = DispatchQueue(label: "com.expensetracker.parsing", qos: .userInitiated)
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = DataParsingService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /**
     * 解析OCR数据为识别结果
     * - Parameter ocrData: OCR识别的原始数据
     * - Returns: 解析后的识别结果
     */
    func parseOCRData(_ ocrData: OCRData) async -> Result<RecognitionResult, AutoRecognitionError> {
        print("🔄 开始解析OCR数据")
        
        await MainActor.run {
            isParsing = true
            parsingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isParsing = false
                parsingProgress = 0.0
            }
        }
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                self.performDataParsing(ocrData) { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * 执行数据解析
     */
    private func performDataParsing(
        _ ocrData: OCRData,
        completion: @escaping (Result<RecognitionResult, AutoRecognitionError>) -> Void
    ) {
        let startTime = Date()
        
        // 更新进度
        Task { @MainActor in
            parsingProgress = 0.1
        }
        
        // 1. 提取金额
        let amounts = extractAmounts(from: ocrData)
        Task { @MainActor in
            parsingProgress = 0.3
        }
        
        // 2. 提取描述信息
        let description = extractDescription(from: ocrData)
        Task { @MainActor in
            parsingProgress = 0.5
        }
        
        // 3. 提取商家名称
        let merchantName = extractMerchantName(from: ocrData)
        Task { @MainActor in
            parsingProgress = 0.7
        }
        
        // 4. 提取时间信息
        let detectedDate = extractDate(from: ocrData)
        Task { @MainActor in
            parsingProgress = 0.8
        }
        
        // 5. 提取支付方式
        let paymentMethod = extractPaymentMethod(from: ocrData)
        Task { @MainActor in
            parsingProgress = 0.9
        }
        
        // 6. 智能分类推荐
        let categoryResult = suggestCategory(from: ocrData, merchantName: merchantName, description: description)
        Task { @MainActor in
            parsingProgress = 1.0
        }
        
        // 验证解析结果
        guard !amounts.isEmpty else {
            print("❌ 未识别到有效金额")
                                    completion(.failure(.noValidAmountFound))
            return
        }
        
        // 创建识别结果
        let recognitionResult = RecognitionResult(
            amounts: amounts,
            description: description,
            merchantName: merchantName,
            detectedDate: detectedDate,
            paymentMethod: paymentMethod,
            rawText: extractAllText(from: ocrData),
            suggestedCategory: categoryResult.category,
            categoryConfidence: categoryResult.confidence,
            ocrConfidence: Double(ocrData.confidence)
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        print("✅ 数据解析完成，耗时\(String(format: "%.2f", processingTime * 1000))ms")
        print("💰 识别金额: \(amounts)")
        print("🏪 商家名称: \(merchantName ?? "未识别")")
        print("📝 描述: \(description ?? "未识别")")
        print("🏷️ 推荐分类: \(categoryResult.category.displayName) (置信度: \(String(format: "%.2f", categoryResult.confidence)))")
        
        completion(.success(recognitionResult))
    }
    
    /**
     * 提取金额信息
     */
    private func extractAmounts(from ocrData: OCRData) -> [Double] {
        var amounts: [Double] = []
        
        // 获取所有可能的金额文本
        let potentialAmountTexts = ocrData.textBlocks
            .filter { $0.isPotentialAmount }
            .map { $0.text }
        
        // 解析每个潜在金额文本
        for text in potentialAmountTexts {
            let extractedAmounts = parseAmountFromText(text)
            amounts.append(contentsOf: extractedAmounts)
        }
        
        // 如果没有找到标记为金额的文本，尝试从所有文本中提取
        if amounts.isEmpty {
            let allTexts = ocrData.textBlocks.map { $0.text }
            for text in allTexts {
                let extractedAmounts = parseAmountFromText(text)
                amounts.append(contentsOf: extractedAmounts)
            }
        }
        
        // 去重并排序
        amounts = Array(Set(amounts)).sorted()
        
        print("💰 提取到的金额: \(amounts)")
        return amounts
    }
    
    /**
     * 从文本中解析金额
     */
    private func parseAmountFromText(_ text: String) -> [Double] {
        var amounts: [Double] = []
        
        // 金额解析正则表达式
        let patterns = [
            "¥([0-9,]+\\.?[0-9]*)",         // ¥123.45
            "\\$([0-9,]+\\.?[0-9]*)",       // $123.45
            "€([0-9,]+\\.?[0-9]*)",         // €123.45
            "([0-9,]+\\.[0-9]{2})元?",      // 123.45元
            "([0-9,]+)元",                  // 123元
            "([0-9,]+\\.[0-9]+)",           // 123.45
            "总计.*?([0-9,]+\\.?[0-9]*)",   // 总计123.45
            "合计.*?([0-9,]+\\.?[0-9]*)",   // 合计123.45
            "应付.*?([0-9,]+\\.?[0-9]*)",   // 应付123.45
            "实付.*?([0-9,]+\\.?[0-9]*)"    // 实付123.45
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: text) {
                        let amountString = String(text[swiftRange])
                        if let amount = parseAmountString(amountString) {
                            amounts.append(amount)
                        }
                    }
                }
            }
        }
        
        return amounts
    }
    
    /**
     * 解析金额字符串为数值
     */
    private func parseAmountString(_ amountString: String) -> Double? {
        // 移除逗号和其他非数字字符（保留小数点）
        let cleanString = amountString.replacingOccurrences(of: ",", with: "")
        
        // 尝试转换为Double
        if let amount = Double(cleanString), amount > 0 {
            return amount
        }
        
        return nil
    }
    
    /**
     * 提取描述信息
     */
    private func extractDescription(from ocrData: OCRData) -> String? {
        // 优先使用商家名称作为描述
        if let merchantName = extractMerchantName(from: ocrData) {
            return merchantName
        }
        
        // 查找可能的商品或服务描述
        let descriptionKeywords = [
            "商品", "服务", "项目", "消费", "购买", "订单", "产品"
        ]
        
        for textBlock in ocrData.textBlocks {
            let text = textBlock.text
            
            // 检查是否包含描述关键词
            for keyword in descriptionKeywords {
                if text.contains(keyword) && text.count > keyword.count {
                    return text
                }
            }
        }
        
        // 如果没有找到特定描述，返回最长的非金额文本
        let nonAmountTexts = ocrData.textBlocks
            .filter { !$0.isPotentialAmount }
            .map { $0.text }
            .filter { $0.count >= 3 && $0.count <= 50 }
        
        return nonAmountTexts.max(by: { $0.count < $1.count })
    }
    
    /**
     * 提取商家名称
     */
    private func extractMerchantName(from ocrData: OCRData) -> String? {
        // 获取所有可能的商家名称
        let potentialMerchants = ocrData.textBlocks
            .filter { $0.isPotentialMerchant }
            .map { $0.text }
        
        // 返回最可能的商家名称（通常是最长的）
        return potentialMerchants.max(by: { $0.count < $1.count })
    }
    
    /**
     * 提取时间信息
     */
    private func extractDate(from ocrData: OCRData) -> Date? {
        let datePatterns = [
            "\\d{4}-\\d{2}-\\d{2}",         // 2023-12-06
            "\\d{4}/\\d{2}/\\d{2}",         // 2023/12/06
            "\\d{2}-\\d{2}-\\d{4}",         // 06-12-2023
            "\\d{2}/\\d{2}/\\d{4}",         // 06/12/2023
            "\\d{4}年\\d{1,2}月\\d{1,2}日", // 2023年12月6日
            "\\d{1,2}月\\d{1,2}日",         // 12月6日
        ]
        
        let dateFormatters = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd-MM-yyyy",
            "dd/MM/yyyy",
            "yyyy年M月d日",
            "M月d日"
        ]
        
        for textBlock in ocrData.textBlocks {
            let text = textBlock.text
            
            for (index, pattern) in datePatterns.enumerated() {
                if let range = text.range(of: pattern, options: .regularExpression) {
                    let dateString = String(text[range])
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = dateFormatters[index]
                    formatter.locale = Locale(identifier: "zh_CN")
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    /**
     * 提取支付方式
     */
    private func extractPaymentMethod(from ocrData: OCRData) -> String? {
        let paymentKeywords = [
            "微信": "wechat",
            "支付宝": "alipay",
            "现金": "cash",
            "银行卡": "bank_card",
            "信用卡": "credit_card",
            "储蓄卡": "debit_card",
            "Apple Pay": "apple_pay",
            "刷卡": "card"
        ]
        
        for textBlock in ocrData.textBlocks {
            let text = textBlock.text
            
            for (keyword, method) in paymentKeywords {
                if text.contains(keyword) {
                    return method
                }
            }
        }
        
        return nil
    }
    
    /**
     * 智能分类推荐 - Phase 3 优化版本
     */
    private func suggestCategory(
        from ocrData: OCRData,
        merchantName: String?,
        description: String?
    ) -> CategorySuggestion {
        
        // 合并所有文本进行分析
        var allText = extractAllText(from: ocrData)
        if let merchant = merchantName {
            allText += " " + merchant
        }
        if let desc = description {
            allText += " " + desc
        }
        
        // 转换为小写以提高匹配准确性
        let normalizedText = allText.lowercased()
        
        // 扩展的分类关键词映射 - Phase 3 优化
        let categoryKeywords: [ExpenseCategory: [String: Double]] = [
            .food: [
                // 餐厅类型
                "餐厅": 1.0, "饭店": 1.0, "酒店": 0.8, "食堂": 1.0, "快餐": 1.0,
                // 饮品
                "咖啡": 1.0, "奶茶": 1.0, "茶饮": 1.0, "果汁": 0.8, "饮料": 0.8,
                // 外卖平台
                "美团": 1.0, "饿了么": 1.0, "外卖": 1.0, "配送": 0.8,
                // 知名品牌
                "麦当劳": 1.0, "肯德基": 1.0, "星巴克": 1.0, "必胜客": 1.0, "海底捞": 1.0,
                "喜茶": 1.0, "瑞幸": 1.0, "蜜雪冰城": 1.0, "华莱士": 1.0,
                // 食物类型
                "食物": 0.9, "饮食": 0.9, "用餐": 0.9, "午餐": 1.0, "晚餐": 1.0, "早餐": 1.0,
                "火锅": 1.0, "烧烤": 1.0, "小吃": 1.0, "甜品": 1.0, "面条": 0.8, "米饭": 0.8
            ],
            .transport: [
                // 打车服务
                "滴滴": 1.0, "出租车": 1.0, "网约车": 1.0, "专车": 1.0, "快车": 1.0,
                // 公共交通
                "地铁": 1.0, "公交": 1.0, "公交车": 1.0, "轻轨": 1.0, "高铁": 1.0, "火车": 1.0,
                // 汽车相关
                "加油": 1.0, "停车": 1.0, "洗车": 0.8, "维修": 0.8, "保养": 0.8,
                // 其他交通
                "高速": 1.0, "过路费": 1.0, "交通": 0.9, "车费": 1.0, "油费": 1.0,
                "共享单车": 1.0, "摩拜": 1.0, "哈啰": 1.0, "青桔": 1.0
            ],
            .shopping: [
                // 电商平台
                "淘宝": 1.0, "京东": 1.0, "天猫": 1.0, "拼多多": 1.0, "苏宁": 1.0,
                // 实体店
                "超市": 1.0, "商场": 1.0, "购物中心": 1.0, "便利店": 1.0, "7-11": 1.0,
                "沃尔玛": 1.0, "家乐福": 1.0, "华润万家": 1.0, "永辉": 1.0,
                // 商品类型
                "购物": 1.0, "服装": 1.0, "化妆品": 1.0, "商品": 0.9, "零售": 0.9,
                "电子产品": 1.0, "数码": 1.0, "家电": 1.0, "日用品": 1.0, "生活用品": 1.0
            ],
            .entertainment: [
                // 娱乐场所
                "电影": 1.0, "影院": 1.0, "ktv": 1.0, "网吧": 1.0, "游戏厅": 1.0,
                // 运动健身
                "健身": 1.0, "运动": 1.0, "游泳": 1.0, "瑜伽": 1.0, "健身房": 1.0,
                // 娱乐活动
                "娱乐": 1.0, "游戏": 1.0, "游乐园": 1.0, "主题公园": 1.0,
                "演唱会": 1.0, "音乐会": 1.0, "话剧": 1.0, "展览": 1.0
            ],
            .bills: [
                // 公用事业
                "电费": 1.0, "水费": 1.0, "燃气费": 1.0, "话费": 1.0, "宽带": 1.0,
                // 房屋相关
                "房租": 1.0, "物业": 1.0, "物业费": 1.0, "管理费": 1.0,
                // 其他账单
                "缴费": 1.0, "账单": 1.0, "费用": 0.8, "服务费": 0.8,
                "保险": 1.0, "保险费": 1.0, "年费": 1.0, "月费": 1.0
            ],
            .healthcare: [
                // 医疗机构
                "医院": 1.0, "诊所": 1.0, "药店": 1.0, "药房": 1.0, "体检": 1.0,
                // 医疗服务
                "医疗": 1.0, "挂号": 1.0, "检查": 1.0, "治疗": 1.0, "手术": 1.0,
                // 药品
                "药品": 1.0, "药物": 1.0, "保健品": 0.8, "维生素": 0.8
            ],
            .education: [
                // 教育机构
                "学校": 1.0, "大学": 1.0, "培训班": 1.0, "培训机构": 1.0,
                // 教育费用
                "学费": 1.0, "培训": 1.0, "教育": 1.0, "课程": 1.0, "辅导": 1.0,
                // 学习用品
                "书店": 1.0, "文具": 1.0, "教材": 1.0, "书籍": 1.0
            ],
            .travel: [
                // 住宿
                "酒店": 1.0, "宾馆": 1.0, "民宿": 1.0, "青旅": 1.0,
                // 交通
                "机票": 1.0, "航空": 1.0, "飞机": 1.0, "船票": 1.0,
                // 旅游
                "旅游": 1.0, "旅行": 1.0, "景点": 1.0, "门票": 1.0, "导游": 1.0
            ]
        ]
        
        var bestCategory = ExpenseCategory.other
        var bestScore = 0.0
        var matchedKeywords: [String] = []
        var detailedScoring: [String: Double] = [:]
        
        // 计算每个分类的匹配分数 - 改进的评分算法
        for (category, keywords) in categoryKeywords {
            var totalScore = 0.0
            var currentMatches: [String] = []
            var keywordCount = 0
            
            for (keyword, weight) in keywords {
                keywordCount += 1
                
                if normalizedText.contains(keyword.lowercased()) {
                    var score = weight
                    
                    // 商家名称匹配权重更高
                    if merchantName?.lowercased().contains(keyword.lowercased()) == true {
                        score *= 1.5
                    }
                    
                    // 描述匹配权重中等
                    if description?.lowercased().contains(keyword.lowercased()) == true {
                        score *= 1.2
                    }
                    
                    // 完整词匹配权重更高
                    if normalizedText.contains(" \(keyword.lowercased()) ") || 
                       normalizedText.hasPrefix("\(keyword.lowercased()) ") ||
                       normalizedText.hasSuffix(" \(keyword.lowercased())") {
                        score *= 1.3
                    }
                    
                    totalScore += score
                    currentMatches.append(keyword)
                }
            }
            
            // 归一化分数 - 考虑关键词数量和匹配质量
            let normalizedScore = totalScore / Double(keywordCount)
            let matchRatio = Double(currentMatches.count) / Double(keywordCount)
            let finalScore = normalizedScore * (0.7 + 0.3 * matchRatio)
            
            detailedScoring[category.displayName] = finalScore
            
            if finalScore > bestScore {
                bestScore = finalScore
                bestCategory = category
                matchedKeywords = currentMatches
            }
        }
        
        // 如果没有匹配到关键词，尝试基于金额范围推测
        if bestScore < 0.1 {
            let amounts = extractAmounts(from: ocrData)
            if let maxAmount = amounts.max() {
                bestCategory = suggestCategoryByAmount(maxAmount)
                bestScore = 0.3 // 给一个中等置信度
                matchedKeywords = ["基于金额推测"]
            } else {
                bestCategory = .other
                bestScore = 0.1
            }
        }
        
        let reason = matchedKeywords.isEmpty ? 
            "未找到匹配关键词，基于金额推测" : 
            "匹配关键词: \(matchedKeywords.joined(separator: ", "))"
        
        print("🏷️ 分类推荐详情:")
        print("   最佳分类: \(bestCategory.displayName) (置信度: \(String(format: "%.3f", bestScore)))")
        print("   匹配关键词: \(matchedKeywords)")
        print("   所有分类评分: \(detailedScoring)")
        
        return CategorySuggestion(
            category: bestCategory,
            confidence: min(bestScore, 1.0), // 确保置信度不超过1.0
            matchedKeywords: matchedKeywords,
            reason: reason
        )
    }
    
    /**
     * 基于金额范围推测分类
     */
    private func suggestCategoryByAmount(_ amount: Double) -> ExpenseCategory {
        switch amount {
        case 0.01...50.0:
            return .food // 小额通常是餐饮
        case 50.01...200.0:
            return .shopping // 中等金额可能是购物
        case 200.01...1000.0:
            return .bills // 较大金额可能是账单
        case 1000.01...:
            return .travel // 大额可能是旅行或大件商品
        default:
            return .other
        }
    }
    
    /**
     * 提取所有文本
     */
    private func extractAllText(from ocrData: OCRData) -> String {
        return ocrData.textBlocks
            .map { $0.text }
            .joined(separator: " ")
    }
}

/**
 * 金额解析配置
 */
struct AmountParsingConfiguration {
    /// 最小金额阈值
    var minimumAmount: Double = 0.01
    
    /// 最大金额阈值
    var maximumAmount: Double = 999999.99
    
    /// 是否允许负数
    var allowNegativeAmounts: Bool = false
    
    /// 小数位数精度
    var decimalPrecision: Int = 2
}

/**
 * 解析统计信息
 */
struct ParsingStatistics {
    /// 总解析次数
    var totalParsingAttempts: Int = 0
    
    /// 成功解析次数
    var successfulParsing: Int = 0
    
    /// 平均解析时间（毫秒）
    var averageParsingTime: Double = 0.0
    
    /// 金额识别成功率
    var amountRecognitionRate: Double = 0.0
    
    /// 商家识别成功率
    var merchantRecognitionRate: Double = 0.0
    
    /// 分类推荐准确率
    var categoryAccuracy: Double = 0.0
} 