import Foundation

/**
 * API响应基础模型
 * 支持可选的message字段，适配不同类型的API响应
 */
struct APIResponse<T: Codable>: Codable {
    /// 请求是否成功
    let success: Bool
    
    /// 响应消息（可选，某些接口可能不返回）
    let message: String?
    
    /// 响应数据（可选，某些接口可能不返回数据）
    let data: T?
    
    /**
     * 初始化方法
     */
    init(success: Bool, message: String? = nil, data: T? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
    
    /**
     * 获取消息内容，提供默认值
     */
    var displayMessage: String {
        return message ?? (success ? "操作成功" : "操作失败")
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
