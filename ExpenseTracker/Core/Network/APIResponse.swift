import Foundation

/**
 * API响应模型
 * 用于包装API返回的数据
 */
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
    
    var isSuccess: Bool {
        return success && data != nil
    }
    
    var errorMessage: String {
        return error ?? message ?? "Unknown error"
    }
    
    init(success: Bool, data: T? = nil, message: String? = nil, error: String? = nil) {
        self.success = success
        self.data = data
        self.message = message
        self.error = error
    }
}

/**
 * 专门用于不返回数据的API响应
 */
struct EmptyAPIResponse: Codable {
    let success: Bool
    let message: String?
    
    var displayMessage: String {
        return message ?? (success ? "操作成功" : "操作失败")
    }
}

/**
 * 用于错误响应的模型
 */
struct ErrorResponse: Codable {
    let success: Bool
    let message: String
    let error: String?
    
    init(success: Bool = false, message: String, error: String? = nil) {
        self.success = success
        self.message = message
        self.error = error
    }
}

// 🚫 移除重复的 init(success:message:)，避免与主初始化器冲突

// Note: OCR-related models have been moved to OCRModels.swift to avoid duplication
// This file now only contains generic API response structures
