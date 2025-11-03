import Foundation

/// 账单解析器协议
protocol ReceiptParserProtocol {
    /// 解析账单文本
    /// - Parameter text: OCR识别的原始文本
    /// - Returns: 解析后的支出数据
    func parse(_ text: String) -> ParsedReceiptData
    
    /// 是否支持该账单类型
    /// - Parameter text: OCR识别的原始文本
    /// - Returns: 是否支持
    func canParse(_ text: String) -> Bool
    
    /// 解析器名称
    var name: String { get }
}

