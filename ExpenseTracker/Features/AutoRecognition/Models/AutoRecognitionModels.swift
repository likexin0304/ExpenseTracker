import Foundation
import UIKit

// MARK: - Auto Expense Data

// 删除重复的AutoExpenseData结构体定义，改为引用AutoExpenseData.swift中的定义

// 🚫 移除重复的 AutoExpenseResult 定义，改用 Services 层 enum AutoExpenseResult

// MARK: - Auto Expense Request

/// 自动识别请求
struct AutoExpenseRequest {
    let image: UIImage?
    let text: String?
    let source: OCRImageSource
    let options: [String: Any]?
    
    init(image: UIImage? = nil, text: String? = nil, source: OCRImageSource = .unknown, options: [String: Any]? = nil) {
        self.image = image
        self.text = text
        self.source = source
        self.options = options
    }
    
    // 添加一个新的初始化方法，用于从OCR文本创建
    init(ocrText: String, amount: Double, category: String, paymentMethod: String, date: Date) {
        self.text = ocrText
        self.image = nil
        self.source = .text
        
        // 创建选项字典
        var opts: [String: Any] = [:]
        opts["amount"] = amount
        opts["category"] = category
        opts["paymentMethod"] = paymentMethod
        
        let dateFormatter = ISO8601DateFormatter()
        opts["date"] = dateFormatter.string(from: date)
        
        self.options = opts
    }
}

// MARK: - Expense Corrections

/// 支出修正
struct ExpenseCorrections: Codable {
    var amount: Double?
    var category: ExpenseCategory?
    var description: String?
    var date: Date?
    var location: String?
    var paymentMethod: PaymentMethod?
    var tags: [String]?
    
    init(amount: Double? = nil, 
         category: ExpenseCategory? = nil, 
         description: String? = nil, 
         date: Date? = nil, 
         location: String? = nil, 
         paymentMethod: PaymentMethod? = nil,
         tags: [String]? = nil) {
        self.amount = amount
        self.category = category
        self.description = description
        self.date = date
        self.location = location
        self.paymentMethod = paymentMethod
        self.tags = tags
    }
    
    var isEmpty: Bool {
        return amount == nil && 
               category == nil && 
               description == nil && 
               date == nil && 
               location == nil && 
               paymentMethod == nil &&
               (tags == nil || tags!.isEmpty)
    }
    
    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case amount, category, description, date, location, paymentMethod, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        category = try container.decodeIfPresent(ExpenseCategory.self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        paymentMethod = try container.decodeIfPresent(PaymentMethod.self, forKey: .paymentMethod)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
    }
} 