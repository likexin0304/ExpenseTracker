import Foundation

/// 账单解析器路由管理器
/// 负责识别账单类型并路由到对应的解析器
class ReceiptParserRouter {
    static let shared = ReceiptParserRouter()
    
    private var parsers: [ReceiptParserProtocol] = []
    private let typeDetector = ReceiptTypeDetector.shared
    
    private init() {
        // 注册所有解析器（按优先级排序）
        parsers = [
            WeChatPayReceiptParser(),
            GenericReceiptParser()  // 通用解析器作为兜底
        ]
        
        print("✅ ReceiptParserRouter初始化完成，已注册\(parsers.count)个解析器")
    }
    
    /// 路由到对应的解析器并解析账单
    /// - Parameter text: OCR识别的原始文本
    /// - Returns: 解析后的支出数据
    func parseReceipt(_ text: String) -> ParsedReceiptData {
        print("🔄 开始路由账单解析...")
        
        // 1. 先识别账单类型
        let (type, confidence) = typeDetector.detectReceiptType(from: text)
        
        // 2. 找到对应的解析器
        if let parser = findParser(for: type) {
            print("✅ 使用 \(parser.name) 解析账单")
            return parser.parse(text)
        }
        
        // 3. 如果没有找到，使用通用解析器
        if let genericParser = parsers.first(where: { $0 is GenericReceiptParser }) {
            print("⚠️ 使用通用解析器（兜底）")
            return genericParser.parse(text)
        }
        
        // 4. 最后兜底：使用原有的PaymentReceiptParser
        print("⚠️ 使用默认PaymentReceiptParser")
        return PaymentReceiptParser.shared.parsePaymentReceipt(text)
    }
    
    /// 查找对应的解析器
    private func findParser(for type: ReceiptType) -> ReceiptParserProtocol? {
        switch type {
        case .wechatPayStandard, .wechatPayRefund:
            return parsers.first(where: { $0 is WeChatPayReceiptParser })
        case .alipayStandard:
            // 未来扩展：支付宝解析器
            return nil
        case .generic:
            return parsers.first(where: { $0 is GenericReceiptParser })
        }
    }
    
    // MARK: - 转换函数
    
    /// 将前端解析结果转换为OCRProcessResult格式
    /// - Parameters:
    ///   - parsedData: 前端解析的账单数据
    ///   - rawText: OCR识别的原始文本
    /// - Returns: OCRProcessResult格式的结果
    func convertToOCRProcessResult(_ parsedData: ParsedReceiptData, rawText: String) -> OCRProcessResult {
        // 构建OCRParsedData
        let ocrParsedData = OCRParsedData(
            merchant: parsedData.merchantName.map { 
                OCRMerchant(value: $0, confidence: parsedData.confidence, originalText: nil) 
            },
            amount: parsedData.amount.map { 
                OCRAmount(value: $0, currency: "CNY", confidence: parsedData.confidence, originalText: nil) 
            },
            date: parsedData.dateTime.map { 
                OCRDate(value: ISO8601DateFormatter().string(from: $0), confidence: parsedData.confidence, originalText: nil) 
            },
            paymentMethod: parsedData.paymentMethod.map { 
                OCRPaymentMethod(value: $0, confidence: parsedData.confidence, originalText: nil) 
            },
            category: parsedData.category != "其他" ? 
                OCRCategory(value: parsedData.category, confidence: parsedData.confidence, source: nil) : nil
        )
        
        // 构建OCRRecord
        let recordId = UUID().uuidString
        let ocrRecord = OCRRecord(
            id: recordId,
            originalText: rawText,
            parsedData: ocrParsedData,
            confidenceScore: parsedData.confidence,
            status: parsedData.isValid ? "success" : "pending",
            suggestions: OCRSuggestions(
                autoCreate: parsedData.confidence >= 0.85 && parsedData.isValid,
                needsReview: parsedData.confidence < 0.85 || !parsedData.isValid,
                confidence: parsedData.confidence >= 0.85 ? "高" : (parsedData.confidence >= 0.7 ? "中" : "低")
            ),
            expenseId: nil,
            errorMessage: parsedData.isValid ? nil : "前端解析结果不完整",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        // 构建OCRProcessResult
        // 如果置信度高且数据有效，可以自动创建（但这里我们设为false，让processRecognitionResult决定）
        let ocrProcessResult = OCRProcessResult(
            record: ocrRecord,
            expense: nil,  // 前端解析不自动创建，让processRecognitionResult处理
            autoConfirmed: false  // 总是需要确认，除非置信度很高
        )
        
        return ocrProcessResult
    }
}

