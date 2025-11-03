import Foundation

/// 通用账单解析器（兜底方案）
/// 当无法识别特定账单类型时使用，使用原有的PaymentReceiptParser逻辑
class GenericReceiptParser: ReceiptParserProtocol {
    var name: String { return "通用解析器" }
    
    func canParse(_ text: String) -> Bool {
        // 通用解析器总是可以解析（作为兜底）
        return true
    }
    
    func parse(_ text: String) -> ParsedReceiptData {
        print("📄 使用通用解析器（兜底方案）")
        
        // 使用原有的PaymentReceiptParser逻辑
        return PaymentReceiptParser.shared.parsePaymentReceipt(text)
    }
}

