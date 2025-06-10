import Foundation

/**
 * 预算数据模型
 * 对应后端Budget模型，用于表示用户的月度预算信息
 */
struct Budget: Codable, Identifiable {
    /// 预算唯一标识符
    let id: Int
    
    /// 所属用户ID
    let userId: Int
    
    /// 预算金额
    let amount: Double
    
    /// 预算年份
    let year: Int
    
    /// 预算月份 (1-12)
    let month: Int
    
    /// 创建时间
    let createdAt: String
    
    /// 更新时间
    let updatedAt: String
    
    /**
     * 获取格式化的预算金额字符串
     * @returns 格式化后的金额字符串，如"¥5,000.00"
     */
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
    
    /**
     * 获取月份显示字符串
     * @returns 格式化的月份字符串，如"2025年6月"
     */
    var monthDisplayString: String {
        return "\(year)年\(month)月"
    }
    
    /**
     * 检查是否为当前月份的预算
     * @returns 是否为当前月份
     */
    var isCurrentMonth: Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        return year == currentYear && month == currentMonth
    }
}

// MARK: - Budget扩展方法
extension Budget {
    /**
     * 从字典创建Budget对象
     * @param dict 包含预算信息的字典
     * @returns Budget对象，如果创建失败则返回nil
     */
    static func from(dict: [String: Any]) -> Budget? {
        guard let id = dict["id"] as? Int,
              let userId = dict["userId"] as? Int,
              let amount = dict["amount"] as? Double,
              let year = dict["year"] as? Int,
              let month = dict["month"] as? Int,
              let createdAt = dict["createdAt"] as? String,
              let updatedAt = dict["updatedAt"] as? String else {
            return nil
        }
        
        return Budget(
            id: id,
            userId: userId,
            amount: amount,
            year: year,
            month: month,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
