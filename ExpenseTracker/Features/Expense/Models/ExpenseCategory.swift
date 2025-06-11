import Foundation
import SwiftUI

/// 支出分类枚举
enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food = "food"
    case transport = "transport"
    case entertainment = "entertainment"
    case shopping = "shopping"
    case bills = "bills"
    case healthcare = "healthcare"
    case education = "education"
    case travel = "travel"
    case other = "other"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .food:
            return "餐饮"
        case .transport:
            return "交通"
        case .entertainment:
            return "娱乐"
        case .shopping:
            return "购物"
        case .bills:
            return "账单"
        case .healthcare:
            return "医疗"
        case .education:
            return "教育"
        case .travel:
            return "旅行"
        case .other:
            return "其他"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .food:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .entertainment:
            return "tv.fill"
        case .shopping:
            return "bag.fill"
        case .bills:
            return "doc.text.fill"
        case .healthcare:
            return "cross.fill"
        case .education:
            return "book.fill"
        case .travel:
            return "airplane"
        case .other:
            return "ellipsis.circle"
        }
    }
    
    /// 分类颜色
    var color: Color {
        switch self {
        case .food:
            return .orange
        case .transport:
            return .blue
        case .entertainment:
            return .purple
        case .shopping:
            return .pink
        case .bills:
            return .red
        case .healthcare:
            return .green
        case .education:
            return .indigo
        case .travel:
            return .cyan
        case .other:
            return .gray
        }
    }
    
    /// 分类描述
    var description: String {
        switch self {
        case .food:
            return "餐厅、外卖、零食等餐饮消费"
        case .transport:
            return "地铁、公交、打车、加油等交通费用"
        case .entertainment:
            return "电影、游戏、KTV等娱乐消费"
        case .shopping:
            return "服装、电子产品、日用品等购物消费"
        case .bills:
            return "水电费、房租、手机费等账单支付"
        case .healthcare:
            return "医院、药店、体检等医疗消费"
        case .education:
            return "培训、书籍、课程等教育投资"
        case .travel:
            return "酒店、机票、门票等旅行消费"
        case .other:
            return "其他未分类的消费"
        }
    }
}

/// 支付方式枚举
enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash = "cash"
    case card = "card"
    case online = "online"
    case other = "other"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .cash:
            return "现金"
        case .card:
            return "银行卡"
        case .online:
            return "在线支付"
        case .other:
            return "其他"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .cash:
            return "banknote"
        case .card:
            return "creditcard"
        case .online:
            return "iphone"
        case .other:
            return "questionmark.circle"
        }
    }
    
    /// 支付方式颜色
    var color: Color {
        switch self {
        case .cash:
            return .green
        case .card:
            return .blue
        case .online:
            return .purple
        case .other:
            return .gray
        }
    }
}

/// 支出统计模型
struct ExpenseStats: Codable {
    let categoryStats: [CategoryStat]
    let totalStats: TotalStat
    let periodStats: [PeriodStat]
}

struct CategoryStat: Codable, Identifiable {
    let id: ExpenseCategory
    let total: Double
    let count: Int
    let avgAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case total, count, avgAmount
    }
    
    /// 格式化的总金额
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: total)) ?? "¥0.00"
    }
    
    /// 格式化的平均金额
    var formattedAvgAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: avgAmount)) ?? "¥0.00"
    }
}

struct TotalStat: Codable {
    let totalAmount: Double
    let totalCount: Int
    let avgAmount: Double
    let maxAmount: Double
    let minAmount: Double
    
    /// 格式化的总金额
    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "¥0.00"
    }
    
    /// 格式化的平均金额
    var formattedAvgAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: avgAmount)) ?? "¥0.00"
    }
    
    /// 格式化的最大金额
    var formattedMaxAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: maxAmount)) ?? "¥0.00"
    }
    
    /// 格式化的最小金额
    var formattedMinAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: minAmount)) ?? "¥0.00"
    }
}

struct PeriodStat: Codable, Identifiable {
    let id: String
    let total: Double
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case total, count
    }
    
    /// 格式化的总金额
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: total)) ?? "¥0.00"
    }
}

/// 支出分类响应模型 - 匹配API文档
struct ExpenseCategoriesResponse: Codable {
    let categories: [ExpenseCategory]
    let total: Int
}

/// 支出统计响应模型
struct ExpenseStatsResponse: Codable {
    let categoryStats: [CategoryStat]
    let totalStats: TotalStat
    let periodStats: [PeriodStat]?
}
