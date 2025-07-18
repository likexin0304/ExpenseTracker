import Foundation

/**
 * 自动识别的支出数据
 * 用于OCR识别后的数据结构
 */
struct AutoExpenseData: Codable {
    let amount: Double?
    let merchant: String?
    let date: String?
    let category: String?
    let paymentMethod: String?
    let notes: String?
    let confidence: Double
    let rawText: String
    
    init(amount: Double? = nil, 
         merchant: String? = nil, 
         date: String? = nil, 
         category: String? = nil, 
         paymentMethod: String? = nil, 
         notes: String? = nil, 
         confidence: Double = 0.0, 
         rawText: String = "") {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.category = category
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.confidence = confidence
        self.rawText = rawText
    }
    
    // 从OCRParsedData创建
    init(recordId: String, parsedData: OCRParsedData, confidence: Double, suggestions: [String]) {
        self.amount = parsedData.amount?.value
        self.merchant = parsedData.merchant?.name
        self.date = parsedData.date?.value
        self.category = parsedData.category?.name
        self.paymentMethod = parsedData.paymentMethod?.type
        self.notes = nil
        self.confidence = confidence
        self.rawText = suggestions.joined(separator: "\n")
    }
}

// MARK: - 支出类别响应 (Auto Recognition 专用)
struct AutoExpenseCategoriesResponse: Codable {
    let categories: [ExpenseCategoryItem]
}

struct ExpenseCategoryItem: Codable {
    let id: String
    let name: String
    let icon: String?
    let color: String?
    
    var displayName: String { name }
}

// 🚫 移除 CreateExpenseRequest 与 Expense 的重复定义，使用 Features/Expense/Models/Expense.swift 中的实现 