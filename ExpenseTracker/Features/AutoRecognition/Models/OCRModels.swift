import Foundation
import UIKit

// MARK: - OCR请求模型

/// OCR解析请求
struct OCRParseRequest: Codable {
    let text: String
}

/// OCR自动创建请求
struct OCRAutoCreateRequest: Codable {
    let text: String
    let autoCreateThreshold: Double
    
    init(text: String, autoCreateThreshold: Double = 0.85) {
        self.text = text
        self.autoCreateThreshold = autoCreateThreshold
    }
}

// MARK: - OCR响应模型

/// OCR解析响应
struct OCRParseResponse: Codable {
    let success: Bool
    let data: OCRParseData?
    let message: String?
}

/// OCR解析数据
struct OCRParseData: Codable {
    let record: OCRRecord
}

/// OCR自动创建响应数据
struct OCRAutoCreateData: Codable {
    let autoCreated: Bool
    let expense: ExpenseResponse?
    let ocrRecord: OCRRecord?
    let recordId: String?
    let confidence: Double?
    let parsedData: OCRParsedData?
    let suggestions: OCRAutoCreateSuggestions?
}

/// OCR确认响应
struct OCRConfirmResponse: Codable {
    let success: Bool
    let data: OCRConfirmData
    let message: String?
}

/// OCR自动创建建议
struct OCRAutoCreateSuggestions: Codable {
    let shouldAutoCreate: Bool
    let needsReview: Bool
    let reason: String?
}

/// OCR统计数据
struct OCRStatisticsData: Codable {
    let totalProcessed: Int
    let successRate: Double
    let averageConfidence: Double
    let autoCreateRate: Double
    let topMerchants: [String: Int]?
    let processingTimeAvg: Double
}

// MARK: - OCR解析结果模型

/// OCR商户信息
struct OCRMerchant: Codable {
    let name: String
    let confidence: Double
}

/// OCR金额信息
struct OCRAmount: Codable {
    let value: Double
    let currency: String
    let confidence: Double
}

/// OCR日期信息
struct OCRDate: Codable {
    let value: String
    let confidence: Double
}

/// OCR支付方式
struct OCRPaymentMethod: Codable {
    let type: String
    let confidence: Double
}

/// OCR类别
struct OCRCategory: Codable {
    let name: String
    let confidence: Double
}

/// OCR解析数据
struct OCRParsedData: Codable {
    let merchant: OCRMerchant?
    let amount: OCRAmount?
    let date: OCRDate?
    let paymentMethod: OCRPaymentMethod?
    let category: OCRCategory?
}

/// OCR建议
struct OCRSuggestions: Codable {
    let autoCreate: Bool
    let needsReview: Bool
    let confidence: String
}

/// OCR记录
struct OCRRecord: Codable, Identifiable {
    let id: String
    let originalText: String
    let parsedData: OCRParsedData
    let confidenceScore: Double
    let status: String
    let suggestions: OCRSuggestions?
    let expenseId: String?
    let errorMessage: String?
    let createdAt: String
}

/// OCR记录详情数据
struct OCRRecordDetailData: Codable {
    let record: OCRRecord
}

/// OCR记录列表数据
struct OCRRecordsData: Codable {
    let records: [OCRRecord]
    let totalCount: Int
    let page: Int
    let limit: Int
}

/// OCR确认数据
struct OCRConfirmData: Codable {
    let expense: ExpenseResponse
    let recordId: String
}

/// OCR处理结果
struct OCRProcessResult {
    let record: OCRRecord
    let expense: ExpenseResponse?
    let autoConfirmed: Bool
    
    var needsUserConfirmation: Bool {
        return !autoConfirmed
    }
}

// MARK: - OCR图像来源

/// OCR图像来源
enum OCRImageSource: String, Codable {
    case camera
    case gallery
    case screenshot
    case clipboard
    case document
    case text
    case unknown
}

// MARK: - OCR处理记录

/// OCR处理记录
struct OCRProcessingRecord: Codable {
    let timestamp: Date
    let source: OCRImageSource
    let success: Bool
    let processingTime: TimeInterval
    let textLength: Int
    let parsedDataCount: Int
    let errorMessage: String?
    
    init(timestamp: Date, source: OCRImageSource, success: Bool, processingTime: TimeInterval, textLength: Int, parsedDataCount: Int, errorMessage: String? = nil) {
        self.timestamp = timestamp
        self.source = source
        self.success = success
        self.processingTime = processingTime
        self.textLength = textLength
        self.parsedDataCount = parsedDataCount
        self.errorMessage = errorMessage
    }
}

// MARK: - 费用响应模型

/// 费用响应
struct ExpenseResponse: Codable, Identifiable {
    let id: String
    let amount: Double
    let category: String
    let description: String
    let date: String
    let location: String?
    let paymentMethod: String
    let tags: [String]?
    let userId: String
    let createdAt: String
    let updatedAt: String?
    
    // 添加一个接受Date类型参数的初始化方法
    init(id: String, amount: Double, category: String, description: String, date: Date, location: String?, paymentMethod: String, tags: [String]?, userId: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.amount = amount
        self.category = category
        self.description = description
        
        // 转换Date为String
        let dateFormatter = ISO8601DateFormatter()
        self.date = dateFormatter.string(from: date)
        
        self.location = location
        self.paymentMethod = paymentMethod
        self.tags = tags
        self.userId = userId
        self.createdAt = dateFormatter.string(from: createdAt)
        self.updatedAt = dateFormatter.string(from: updatedAt)
    }
}

// MARK: - OCR商户列表数据

/// OCR商户列表数据
struct OCRMerchantsData: Codable {
    let merchants: [OCRMerchantData]
    let totalCount: Int
    let page: Int
    let limit: Int
}

/// OCR商户数据
struct OCRMerchantData: Codable {
    let id: String
    let name: String
    let category: String?
    let logoUrl: String?
    let occurrences: Int
}

// MARK: - OCR商户匹配

/// OCR商户匹配请求
struct OCRMerchantMatchRequest: Codable {
    let text: String
    let minConfidence: Double
    let maxResults: Int
}

/// OCR商户匹配数据
struct OCRMerchantMatchData: Codable {
    let matches: [OCRMerchantMatch]
}

/// OCR商户匹配结果
struct OCRMerchantMatch: Codable {
    let merchantId: String
    let name: String
    let confidence: Double
    let category: String?
}

// MARK: - 解析后的支出数据

/// 解析后的支出数据
struct ParsedExpenseData {
    let amount: Double
    let category: String
    let description: String
    let merchant: String
    let date: String?
    let location: String?
    let paymentMethod: String?
}

// MARK: - OCR商户统计

/// OCR商户统计
struct OCRMerchantStats: Codable {
    let merchantId: String
    let name: String
    let occurrences: Int
    let averageAmount: Double?
    let category: String?
}

// MARK: - OCR结果

/// OCR结果
struct OCRResult {
    let rawText: String
    let parsedData: [String: Any]
    let sourceImage: UIImage?
    let source: OCRImageSource
    let timestamp: Date
    let processingTime: TimeInterval
    
    // 添加一个简化的初始化方法
    init(rawText: String, processingTime: TimeInterval = 0, timestamp: Date = Date()) {
        self.rawText = rawText
        self.parsedData = [:]
        self.sourceImage = nil
        self.source = .text
        self.timestamp = timestamp
        self.processingTime = processingTime
    }
    
    // 完整的初始化方法
    init(rawText: String, parsedData: [String: Any], sourceImage: UIImage?, source: OCRImageSource, timestamp: Date, processingTime: TimeInterval) {
        self.rawText = rawText
        self.parsedData = parsedData
        self.sourceImage = sourceImage
        self.source = source
        self.timestamp = timestamp
        self.processingTime = processingTime
    }
}

// MARK: - OCRResult 扩展 - 便捷访问字段

extension OCRResult {
    /// 商家名称
    var merchant: String? {
        if let record = parsedData["record"] as? OCRRecord {
            return record.parsedData.merchant?.name
        }
        return nil
    }
    
    /// 金额数值
    var amount: Double? {
        if let record = parsedData["record"] as? OCRRecord {
            return record.parsedData.amount?.value
        }
        return nil
    }
    
    /// 交易日期
    var date: Date? {
        if let record = parsedData["record"] as? OCRRecord,
           let dateString = record.parsedData.date?.value {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }
        return nil
    }
    
    /// 分类名称
    var category: String? {
        if let record = parsedData["record"] as? OCRRecord {
            return record.parsedData.category?.name
        }
        return nil
    }
    
    /// 置信度得分
    var confidence: Double? {
        if let record = parsedData["record"] as? OCRRecord {
            return record.confidenceScore
        }
        return nil
    }
}

/// 自动OCR历史记录项
struct AutoOCRHistoryItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let parseResult: OCRParseResponse
    let autoCreated: Bool
    let isTest: Bool
}

// MARK: - OCR API Request Models

/// OCR确认请求模型
struct OCRConfirmRequest: Codable {
    let confirmed: Bool
    let corrections: [String: Any]?
    
    init(confirmed: Bool, corrections: [String: Any]? = nil) {
        self.confirmed = confirmed
        self.corrections = corrections
    }
    
    // 手动实现Codable，因为corrections包含Any类型
    enum CodingKeys: String, CodingKey {
        case confirmed
        case corrections
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(confirmed, forKey: .confirmed)
        
        if let corrections = corrections {
            // 将corrections转换为JSON数据
            let jsonData = try JSONSerialization.data(withJSONObject: corrections)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            try container.encode(jsonString, forKey: .corrections)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmed = try container.decode(Bool.self, forKey: .confirmed)
        
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .corrections),
           let jsonData = jsonString.data(using: .utf8) {
            corrections = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        } else {
            corrections = nil
        }
    }
}

/// OCR解析数据包装器，提供便利的访问方式
struct OCRParsedDataWrapper {
    private let record: OCRRecord?
    
    init(record: OCRRecord?) {
        self.record = record
    }
    
    var rawText: String? {
        return record?.originalText
    }
    
    var merchant: String? {
        return record?.parsedData.merchant?.name
    }
    
    var amount: Double? {
        return record?.parsedData.amount?.value
    }
    
    var date: String? {
        return record?.parsedData.date?.value
    }
    
    var paymentMethod: String? {
        return record?.parsedData.paymentMethod?.type
    }
    
    var category: String? {
        return record?.parsedData.category?.name
    }
    
    var shouldAutoCreate: Bool {
        return record?.suggestions?.autoCreate ?? false
    }
    
    var needsReview: Bool {
        return record?.suggestions?.needsReview ?? true
    }
    
    var confidenceScore: Double {
        return record?.confidenceScore ?? 0.0
    }
}

// MARK: - OCR Extraction Models

/// OCR提取结果
struct OCRExtractionResult {
    let text: String
    let confidence: Double
    let boundingBox: CGRect
}

/// OCR文本块类型
enum OCRTextBlockType: String {
    case text
    case number
    case date
    case currency
    case merchant
    case total
    case unknown
}

// MARK: - OCR Processing Models

/// OCR处理状态
enum OCRProcessingStatus: String {
    case idle = "空闲"
    case capturing = "捕获中"
    case processing = "处理中"
    case analyzing = "分析中"
    case completed = "完成"
    case failed = "失败"
}

/// OCR处理配置
struct OCRProcessingConfig {
    let preferredLanguages: [String]
    let recognitionLevel: OCRRecognitionLevel
    let confidenceThreshold: Double
    let useCache: Bool
    let useAutoCorrection: Bool
    
    static let `default` = OCRProcessingConfig(
        preferredLanguages: ["zh-Hans", "en-US"],
        recognitionLevel: .accurate,
        confidenceThreshold: 0.7,
        useCache: true,
        useAutoCorrection: true
    )
}

/// OCR识别级别
enum OCRRecognitionLevel: String {
    case fast
    case balanced
    case accurate
}

// MARK: - OCR Test Models

/// OCR测试结果
struct OCRTestResult {
    let success: Bool
    let processingTime: TimeInterval
    let rawText: String?
    let parsedData: OCRParsedDataWrapper?
    let errorMessage: String?
    let timestamp: Date
    
    init(success: Bool, processingTime: TimeInterval, rawText: String? = nil, parsedData: OCRParsedDataWrapper? = nil, errorMessage: String? = nil) {
        self.success = success
        self.processingTime = processingTime
        self.rawText = rawText
        self.parsedData = parsedData
        self.errorMessage = errorMessage
        self.timestamp = Date()
    }
} 