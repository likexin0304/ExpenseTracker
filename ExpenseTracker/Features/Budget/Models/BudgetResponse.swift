import Foundation

/**
 * 预算统计信息模型
 * 包含预算使用情况的各种统计数据
 */
struct BudgetStatistics: Codable {
    /// 预算总金额
    let budgetAmount: Double
    
    /// 已花费总金额
    let totalExpenses: Double
    
    /// 剩余预算金额
    let remainingBudget: Double
    
    /// 预算使用百分比 (0-100)
    let usagePercentage: Double
    
    /// 统计年份
    let year: Int
    
    /// 统计月份
    let month: Int
    
    /**
     * 获取格式化的预算金额
     */
    var formattedBudgetAmount: String {
        return formatCurrency(budgetAmount)
    }
    
    /**
     * 获取格式化的已花费金额
     */
    var formattedTotalExpenses: String {
        return formatCurrency(totalExpenses)
    }
    
    /**
     * 获取格式化的剩余预算
     */
    var formattedRemainingBudget: String {
        return formatCurrency(remainingBudget)
    }
    
    /**
     * 获取使用百分比的显示字符串
     */
    var usagePercentageString: String {
        return String(format: "%.1f%%", usagePercentage)
    }
    
    /**
     * 判断是否超支
     */
    var isOverBudget: Bool {
        return totalExpenses > budgetAmount
    }
    
    /**
     * 获取预算状态颜色
     */
    var statusColor: String {
        if isOverBudget {
            return "red"
        } else if usagePercentage > 80 {
            return "orange"
        } else if usagePercentage > 60 {
            return "yellow"
        } else {
            return "green"
        }
    }
    
    /**
     * 格式化货币金额的私有方法
     */
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
}

/**
 * 设置预算请求模型
 */
struct SetBudgetRequest: Codable {
    /// 预算金额
    let amount: Double
    
    /// 年份 (可选，默认当前年份)
    let year: Int?
    
    /// 月份 (可选，默认当前月份)
    let month: Int?
    
    /**
     * 初始化设置预算请求
     * @param amount 预算金额
     * @param year 年份，默认为当前年份
     * @param month 月份，默认为当前月份
     */
    init(amount: Double, year: Int? = nil, month: Int? = nil) {
        self.amount = amount
        self.year = year
        self.month = month
    }
}

/**
 * 设置预算响应模型
 */
struct SetBudgetResponse: Codable {
    /// 设置后的预算信息
    let budget: Budget
}

/**
 * 获取预算状态响应模型
 */
struct BudgetStatusResponse: Codable {
    /// 预算信息 (可能为空，如果用户还未设置预算)
    let budget: Budget?
    
    /// 预算统计信息
    let statistics: BudgetStatistics
}

/**
 * 预算状态API响应模型（包装后端标准响应格式）
 */
struct BudgetStatusAPIResponse: Codable {
    /// 请求是否成功
    let success: Bool
    
    /// 响应数据
    let data: BudgetStatusResponse
    
    /// 错误消息（可选）
    let message: String?
}

/**
 * 预算历史响应模型
 */
struct BudgetHistoryResponse: Codable {
    /// 预算历史列表
    let budgets: [Budget]
}

// MARK: - 扩展方法
extension BudgetStatistics {
    /**
     * 获取预算使用进度 (0.0 - 1.0)
     * 用于进度条显示
     */
    var usageProgress: Double {
        if budgetAmount <= 0 {
            return 0.0
        }
        
        let progress = totalExpenses / budgetAmount
        return min(max(progress, 0.0), 1.0) // 限制在0-1之间
    }
    
    /**
     * 获取预算状态描述文本
     */
    var statusDescription: String {
        if budgetAmount <= 0 {
            return "未设置预算"
        }
        
        if isOverBudget {
            let overAmount = totalExpenses - budgetAmount
            return "已超支 \(formatCurrency(overAmount))"
        } else if remainingBudget <= 0 {
            return "预算已用完"
        } else {
            return "剩余 \(formattedRemainingBudget)"
        }
    }
    
    /**
     * 获取预算建议文本
     */
    var suggestion: String {
        if budgetAmount <= 0 {
            return "建议设置月度预算来管理支出"
        }
        
        if isOverBudget {
            return "本月支出已超预算，建议控制消费"
        } else if usagePercentage > 80 {
            return "预算使用已达80%，请注意控制支出"
        } else if usagePercentage > 60 {
            return "预算使用良好，继续保持"
        } else {
            return "支出控制良好，可适当增加必要消费"
        }
    }
}
