import Foundation

/**
 * OCR文本类型 - Phase 3 新增
 */
enum OCRTextType: Equatable {
    case amount      // 金额
    case currency    // 货币符号
    case date        // 日期
    case time        // 时间
    case merchant    // 商家名称
    case header      // 标题
    case general     // 一般文本
}

/**
 * 自动识别结果数据模型
 * 包含OCR识别到的所有信息和智能解析结果
 */
struct RecognitionResult: Equatable {
    // MARK: - 识别到的原始数据
    
    /// 识别到的所有金额
    let amounts: [Double]
    
    /// 计算后的总金额
    let totalAmount: Double
    
    /// 商品/服务描述
    let description: String?
    
    /// 商家名称
    let merchantName: String?
    
    /// 检测到的交易时间
    let detectedDate: Date?
    
    /// 识别到的支付方式
    let paymentMethod: String?
    
    /// OCR识别的原始文本
    let rawText: String
    
    // MARK: - 智能分析结果
    
    /// 推荐的支出分类
    let suggestedCategory: ExpenseCategory
    
    /// 分类推荐的置信度 (0.0 - 1.0)
    let categoryConfidence: Double
    
    /// OCR识别的整体置信度 (0.0 - 1.0)
    let ocrConfidence: Double
    
    /// 识别时间戳
    let recognitionTimestamp: Date
    
    // MARK: - 用户编辑的数据
    
    /// 用户选择的金额（用于多金额情况）
    var selectedAmount: Double?
    
    /// 用户编辑的描述
    var editedDescription: String?
    
    /// 用户编辑的交易时间
    var editedTransactionTime: Date?
    
    // MARK: - 初始化方法
    
    init(
        amounts: [Double],
        description: String? = nil,
        merchantName: String? = nil,
        detectedDate: Date? = nil,
        paymentMethod: String? = nil,
        rawText: String,
        suggestedCategory: ExpenseCategory = .other,
        categoryConfidence: Double = 0.0,
        ocrConfidence: Double = 0.0
    ) {
        self.amounts = amounts
        self.totalAmount = amounts.reduce(0, +)
        self.description = description
        self.merchantName = merchantName
        self.detectedDate = detectedDate
        self.paymentMethod = paymentMethod
        self.rawText = rawText
        self.suggestedCategory = suggestedCategory
        self.categoryConfidence = categoryConfidence
        self.ocrConfidence = ocrConfidence
        self.recognitionTimestamp = Date()
    }
    
    // MARK: - 计算属性
    
    /// 是否识别成功（有有效金额）
    var isValid: Bool {
        return totalAmount > 0 && !amounts.isEmpty
    }
    
    /// 是否有高置信度的分类推荐
    var hasHighConfidenceCategory: Bool {
        return categoryConfidence > 0.7
    }
    
    /// 格式化的金额字符串
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "¥0.00"
    }
    
    /// 最佳描述（优先使用商家名称，其次是描述）
    var bestDescription: String {
        if let merchantName = merchantName, !merchantName.isEmpty {
            return merchantName
        }
        return description ?? "未知消费"
    }
    
    /// 推荐的支出记录创建请求
    func toCreateExpenseRequest() -> CreateExpenseRequest {
        return CreateExpenseRequest(
            amount: totalAmount,
            category: suggestedCategory.rawValue,
            description: bestDescription,
            date: detectedDate ?? Date(),
            location: nil, // 暂不支持位置识别
            paymentMethod: paymentMethod ?? "cash",
            tags: [] // 暂不支持标签识别
        )
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RecognitionResult, rhs: RecognitionResult) -> Bool {
        return lhs.amounts == rhs.amounts &&
               lhs.totalAmount == rhs.totalAmount &&
               lhs.description == rhs.description &&
               lhs.merchantName == rhs.merchantName &&
               lhs.detectedDate == rhs.detectedDate &&
               lhs.paymentMethod == rhs.paymentMethod &&
               lhs.rawText == rhs.rawText &&
               lhs.suggestedCategory == rhs.suggestedCategory &&
               lhs.categoryConfidence == rhs.categoryConfidence &&
               lhs.ocrConfidence == rhs.ocrConfidence &&
               lhs.recognitionTimestamp == rhs.recognitionTimestamp
    }
}

/**
 * OCR识别的原始数据 - Phase 3 优化版本
 */
struct OCRData: Equatable {
    /// 识别到的文本块
    let textBlocks: [OCRTextBlock]
    
    /// 整体置信度
    let confidence: Float
    
    /// 识别耗时（毫秒）
    let processingTime: TimeInterval
    
    /// 原始图片尺寸
    let imageSize: CGSize
}

/**
 * OCR文本块数据 - Phase 3 优化版本
 */
struct OCRTextBlock: Equatable {
    /// 文本内容
    let text: String
    
    /// 置信度
    let confidence: Float
    
    /// 在图片中的位置
    let boundingBox: CGRect
    
    /// 文本类型
    let textType: OCRTextType
    
    /// 是否可能是金额
    let isPotentialAmount: Bool
    
    /// 是否可能是商家名称
    let isPotentialMerchant: Bool
}

/**
 * 兼容性：保留旧的TextBlock定义
 */
typealias TextBlock = OCRTextBlock

/**
 * 智能分类推荐结果
 */
struct CategorySuggestion: Equatable {
    /// 推荐的分类
    let category: ExpenseCategory
    
    /// 置信度
    let confidence: Double
    
    /// 匹配的关键词
    let matchedKeywords: [String]
    
    /// 推荐原因
    let reason: String
} 