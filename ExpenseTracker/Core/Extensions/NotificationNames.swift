import Foundation

/**
 * 应用通知名称常量
 * 用于各个模块之间的数据同步通信
 */
extension Notification.Name {
    /// 支出数据发生变化的通知
    static let expenseDataChanged = Notification.Name("expenseDataChanged")
    
    /// 预算数据发生变化的通知
    static let budgetDataChanged = Notification.Name("budgetDataChanged")
    
    /// 用户认证状态发生变化的通知
    static let authStateChanged = Notification.Name("authStateChanged")
}

/**
 * 通知用户信息键
 */
struct NotificationUserInfoKeys {
    /// 操作类型键
    static let operationType = "operationType"
    
    /// 支出ID键
    static let expenseId = "expenseId"
    
    /// 预算ID键
    static let budgetId = "budgetId"
}

/**
 * 数据操作类型
 */
enum DataOperationType: String {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case refreshed = "refreshed"
} 