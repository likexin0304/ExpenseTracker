import Foundation
import Combine

/**
 * 预算服务类
 * 负责处理所有与预算相关的网络请求和数据操作
 */
class BudgetService: ObservableObject {
    // MARK: - 单例模式
    static let shared = BudgetService()
    
    // MARK: - 私有属性
    private let networkManager = NetworkManager.shared
    private let authService = AuthService.shared
    
    // MARK: - 发布属性
    @Published var currentBudget: Budget?
    @Published var currentStatistics: BudgetStatistics?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - 私有初始化
    private init() {
        print("💰 BudgetService初始化")
    }
    
    // MARK: - 公共方法
    
    /**
     * 设置或更新月度预算
     * @param amount 预算金额
     * @param year 年份（可选，默认当前年份）
     * @param month 月份（可选，默认当前月份）
     * @returns 返回Void的Publisher，用于处理成功或失败
     */
    // 在BudgetService.swift中，更新以下方法：

    /**
     * 设置或更新月度预算
     */
    func setBudget(amount: Double, year: Int? = nil, month: Int? = nil) -> AnyPublisher<Void, NetworkError> {
        print("💰 开始设置预算: ¥\(amount)")
        
        // 输入验证
        guard amount > 0 else {
            print("❌ 预算金额无效: \(amount)")
            return Fail(error: NetworkError.serverError("预算金额必须大于0"))
                .eraseToAnyPublisher()
        }
        
        guard amount <= 1000000 else {
            print("❌ 预算金额过大: \(amount)")
            return Fail(error: NetworkError.serverError("预算金额不能超过100万"))
                .eraseToAnyPublisher()
        }
        
        let request = SetBudgetRequest(amount: amount, year: year, month: month)
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            print("❌ 预算请求编码失败")
            return Fail(error: NetworkError.decodingError)
                .eraseToAnyPublisher()
        }
        
        // 获取认证Token
        guard let token = getAuthToken() else {
            return Fail(error: NetworkError.serverError("用户未登录"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        return networkManager.request(
            endpoint: "/budget",
            method: .POST,
            body: requestData,
            headers: headers,
            responseType: SetBudgetResponse.self
        )
        .map { [weak self] response in
            print("📧 设置预算响应: success=\(response.success)")
            if response.success, let budgetData = response.data {
                print("✅ 预算设置成功: \(budgetData.budget.formattedAmount)")
                self?.currentBudget = budgetData.budget
                
                // 设置预算后自动刷新统计数据
                self?.refreshBudgetStatus()
            } else {
                let errorMsg = response.message ?? "设置预算失败"
                print("❌ 设置预算失败: \(errorMsg)")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }

    /**
     * 获取当前月度预算状态
     */
    func getCurrentBudgetStatus() -> AnyPublisher<Void, NetworkError> {
        print("📊 获取当前预算状态")
        
        guard let token = getAuthToken() else {
            return Fail(error: NetworkError.serverError("用户未登录"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        return networkManager.request(
            endpoint: "/budget/current",
            method: .GET,
            headers: headers,
            responseType: BudgetStatusResponse.self
        )
        .map { [weak self] response in
            print("📧 预算状态响应: success=\(response.success)")
            if response.success, let statusData = response.data {
                print("✅ 预算状态获取成功")
                
                // 更新当前预算和统计信息
                self?.currentBudget = statusData.budget
                self?.currentStatistics = statusData.statistics
                
                if let budget = statusData.budget {
                    print("💰 当前预算: \(budget.formattedAmount)")
                } else {
                    print("💰 未设置预算")
                }
                
                let stats = statusData.statistics
                print("📊 支出统计: 已花费\(stats.formattedTotalExpenses), 使用率\(stats.usagePercentageString)")
                
            } else {
                let errorMsg = response.message ?? "获取预算状态失败"
                print("❌ 获取预算状态失败: \(errorMsg)")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 刷新预算状态（内部方法）
     * 用于在设置预算后自动更新统计数据
     */
    private func refreshBudgetStatus() {
        getCurrentBudgetStatus()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 刷新预算状态失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 预算状态刷新成功")
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * 删除当前预算
     * @returns 返回Void的Publisher
     */
    func deleteBudget() -> AnyPublisher<Void, NetworkError> {
        print("🗑️ 删除当前预算")
        
        guard let budget = currentBudget else {
            return Fail(error: NetworkError.serverError("没有预算可删除"))
                .eraseToAnyPublisher()
        }
        
        guard let token = getAuthToken() else {
            return Fail(error: NetworkError.serverError("用户未登录"))
                .eraseToAnyPublisher()
        }
        
        let headers = ["Authorization": "Bearer \(token)"]
        
        return networkManager.request(
            endpoint: "/budget/delete/\(budget.id)",
            method: .DELETE,
            headers: headers,
            responseType: EmptyResponse.self
        )
        .map { [weak self] response in
            if response.success {
                print("✅ 预算删除成功")
                self?.currentBudget = nil
                self?.currentStatistics = nil
            } else {
                print("❌ 删除预算失败: \(response.message)")
            }
            return ()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 辅助方法
    
    /**
     * 检查是否已设置预算
     */
    var hasBudget: Bool {
        return currentBudget != nil
    }
    
    /**
     * 获取当前预算金额
     */
    var currentBudgetAmount: Double {
        return currentBudget?.amount ?? 0.0
    }
    
    /**
     * 获取当前已花费金额
     */
    var currentExpensesAmount: Double {
        return currentStatistics?.totalExpenses ?? 0.0
    }
    
    /**
     * 获取预算使用百分比
     */
    var usagePercentage: Double {
        return currentStatistics?.usagePercentage ?? 0.0
    }
    
    /**
     * 检查是否超支
     */
    var isOverBudget: Bool {
        return currentStatistics?.isOverBudget ?? false
    }
    
    // MARK: - 私有方法
    
    /**
     * 获取认证Token
     */
    private func getAuthToken() -> String? {
        // 这里需要从AuthService获取token
        // 假设AuthService有方法获取当前token
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    /**
     * 清除预算数据
     * 用于用户登出时清理数据
     */
    func clearBudgetData() {
        print("🧹 清除预算数据")
        currentBudget = nil
        currentStatistics = nil
        isLoading = false
        errorMessage = ""
    }
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - 空响应模型（用于删除操作）
struct EmptyResponse: Codable {
    // 空结构体，用于不需要返回数据的API响应
}

// MARK: - BudgetService扩展 - 便捷方法
extension BudgetService {
    /**
     * 格式化货币显示
     */
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
    
    /**
     * 获取预算状态颜色名称（用于UI）
     */
    var statusColorName: String {
        return currentStatistics?.statusColor ?? "gray"
    }
    
    /**
     * 获取预算建议文本
     */
    var budgetSuggestion: String {
        return currentStatistics?.suggestion ?? "建议设置月度预算来管理支出"
    }
}
