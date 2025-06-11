import Foundation

/// 支出记录数据模型 - 与API文档完全匹配
struct Expense: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let amount: Double
    let category: String
    let description: String
    let date: Date
    let location: String?
    let paymentMethod: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - 编码键
    enum CodingKeys: String, CodingKey {
        case id, userId, amount, category, description, date
        case location, paymentMethod, tags
        case createdAt, updatedAt
    }
    
    // MARK: - 自定义解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 必需字段
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        
        // 日期字段处理 - 支持ISO8601格式
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = formatter.date(from: dateString) ?? Date()
        
        // 可选字段
        location = try container.decodeIfPresent(String.self, forKey: .location)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? "cash"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        
        // 时间戳字段
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = formatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = formatter.date(from: updatedAtString) ?? Date()
    }
    
    // MARK: - 计算属性
    
    /// 格式化的金额显示
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
    
    /// 格式化的日期显示
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 格式化的时间显示
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 是否为今天的支出
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// 是否为本周的支出
    var isThisWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 是否为本月的支出
    var isThisMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }
}

/// 创建支出请求模型 - 匹配API文档
struct CreateExpenseRequest: Codable {
    let amount: Double
    let category: String
    let description: String
    let date: String? // API期望ISO8601字符串格式
    let location: String?
    let paymentMethod: String
    let tags: [String]
    
    init(amount: Double, category: String, description: String, 
         date: Date? = nil, location: String? = nil, 
         paymentMethod: String = "cash", tags: [String] = []) {
        self.amount = amount
        self.category = category
        self.description = description
        self.location = location
        self.paymentMethod = paymentMethod
        self.tags = tags
        
        // 转换日期为ISO8601字符串
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.date = formatter.string(from: date)
        } else {
            self.date = nil
        }
    }
}

/// 更新支出请求模型 - 所有字段都是可选的
struct UpdateExpenseRequest: Codable {
    let amount: Double?
    let category: String?
    let description: String?
    let date: String? // API期望ISO8601字符串格式
    let location: String?
    let paymentMethod: String?
    let tags: [String]?
    
    init(amount: Double? = nil, category: String? = nil, description: String? = nil,
         date: Date? = nil, location: String? = nil,
         paymentMethod: String? = nil, tags: [String]? = nil) {
        self.amount = amount
        self.category = category
        self.description = description
        self.location = location
        self.paymentMethod = paymentMethod
        self.tags = tags
        
        // 转换日期为ISO8601字符串
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.date = formatter.string(from: date)
        } else {
            self.date = nil
        }
    }
}

/// 支出列表响应模型
struct ExpensesListResponse: Codable {
    let expenses: [Expense]
    let pagination: ExpensePagination
}

/// 分页信息模型 - 匹配API文档
struct ExpensePagination: Codable {
    let current: Int
    let pages: Int
    let total: Int
    let limit: Int
}

/// 支出数据模型（与ExpensesListResponse相同，为了兼容性）
typealias ExpensesData = ExpensesListResponse

// MARK: - 测试数据支持
#if DEBUG
extension Expense {
    static let mockData = [
        Expense(
            id: 1, userId: 1, amount: 299.99, category: "餐饮", 
            description: "午餐费用", date: Date(), location: "北京市朝阳区",
            paymentMethod: "支付宝", tags: ["工作餐"],
            createdAt: Date(), updatedAt: Date()
        )
    ]
    
    /// 创建示例数据的静态方法
    static func sample() -> Expense {
        return mockData.first!
    }
}

extension Expense {
    init(id: Int, userId: Int, amount: Double, category: String, 
         description: String, date: Date, location: String? = nil,
         paymentMethod: String = "cash", tags: [String] = [],
         createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.category = category
        self.description = description
        self.date = date
        self.location = location
        self.paymentMethod = paymentMethod
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
#endif
