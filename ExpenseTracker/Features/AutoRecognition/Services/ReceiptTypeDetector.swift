import Foundation

/// 账单类型枚举
enum ReceiptType: String, CaseIterable {
    case wechatPayStandard = "微信支付标准账单"
    case wechatPayRefund = "微信支付退款账单"
    case alipayStandard = "支付宝标准账单"
    case generic = "通用账单"
    
    /// 显示名称
    var displayName: String {
        return self.rawValue
    }
}

/// 账单类型识别器
class ReceiptTypeDetector {
    static let shared = ReceiptTypeDetector()
    
    private init() {}
    
    /// 识别账单类型
    /// - Parameter text: OCR识别的原始文本
    /// - Returns: 识别到的账单类型和置信度
    func detectReceiptType(from text: String) -> (type: ReceiptType, confidence: Double) {
        let normalizedText = text.lowercased()
        var scores: [ReceiptType: Double] = [:]
        
        // 检测退款标识
        let refundKeywords = ["Refund Records", "Fully refunded", "退款", "已退款", "Refund"]
        let hasRefundIndicator = refundKeywords.contains { normalizedText.contains($0.lowercased()) }
        
        // 微信支付特征
        let wechatKeywords = ["微信支付", "wechat", "wechat pay", "微信", "支付成功", "Payment successful"]
        let wechatScore = calculateKeywordScore(text: normalizedText, keywords: wechatKeywords)
        
        if hasRefundIndicator && wechatScore > 0.3 {
            // 微信支付退款账单
            scores[.wechatPayRefund] = wechatScore * 1.2  // 退款账单权重更高
        } else if wechatScore > 0.3 {
            // 微信支付标准账单
            scores[.wechatPayStandard] = wechatScore
        }
        
        // 支付宝特征（未来扩展）
        let alipayKeywords = ["支付宝", "alipay", "蚂蚁", "alipay.com"]
        let alipayScore = calculateKeywordScore(text: normalizedText, keywords: alipayKeywords)
        if alipayScore > 0.3 {
            scores[.alipayStandard] = alipayScore
        }
        
        // 找到得分最高的类型
        let bestMatch = scores.max(by: { $0.value < $1.value })
        
        if let best = bestMatch, best.value > 0.3 {
            print("🎯 识别到账单类型: \(best.key.displayName) (置信度: \(String(format: "%.2f", best.value)))")
            return (best.key, best.value)
        } else {
            print("⚠️ 未识别到特定账单类型，使用通用解析器")
            return (.generic, 0.0)
        }
    }
    
    /// 计算关键词匹配得分
    private func calculateKeywordScore(text: String, keywords: [String]) -> Double {
        var score = 0.0
        var matchedCount = 0
        
        for keyword in keywords {
            let lowercasedKeyword = keyword.lowercased()
            if text.contains(lowercasedKeyword) {
                score += 1.0
                matchedCount += 1
                
                // 完整词匹配权重更高
                let wordPattern = "\\b\(lowercasedKeyword)\\b"
                if text.range(of: wordPattern, options: .regularExpression) != nil {
                    score += 0.5
                }
            }
        }
        
        // 归一化得分 (0.0 - 1.0)
        let maxPossibleScore = Double(keywords.count) * 1.5
        return maxPossibleScore > 0 ? min(score / maxPossibleScore, 1.0) : 0.0
    }
}

