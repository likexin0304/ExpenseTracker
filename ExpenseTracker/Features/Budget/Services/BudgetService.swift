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
        
        // 获取认证Token
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法设置预算")
            // 静默返回，不显示错误
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetSet,
            method: .POST,
            body: request,
            responseType: APIResponse<SetBudgetResponse>.self
        )
        .tryMap { [weak self] response in
            print("📦 收到设置预算响应: success=\(response.success)")
            
            guard response.success else {
                let errorMessage = response.message ?? "设置预算失败"
                print("❌ 设置预算失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 预算设置成功: \(data.budget.formattedAmount)")
            self?.currentBudget = data.budget
            
            // 设置预算后自动刷新统计数据
            self?.refreshBudgetStatus()
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                print("❌ 预算设置解析失败: \(error)")
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }

    /**
     * 获取当前月度预算状态
     */
    func getCurrentBudgetStatus() -> AnyPublisher<Void, NetworkError> {
        print("📊 获取当前预算状态")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，跳过预算数据获取")
            // 静默返回，不显示错误
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetCurrent,
            method: .GET,
            responseType: APIResponse<BudgetStatusResponse>.self
        )
        .tryMap { [weak self] response in
            print("📦 收到预算状态响应: success=\(response.success)")
            
            guard response.success else {
                let errorMessage = response.message ?? "获取预算状态失败"
                print("❌ 获取预算状态失败: \(errorMessage)")
                // ✅ 如果后端返回401，message通常是"无效的认证令牌"或"未提供认证令牌"
                // 这种情况下，应该抛出unauthorized错误，而不是serverError
                if errorMessage.contains("认证令牌") || errorMessage.contains("未提供") || errorMessage.contains("未授权") {
                    throw NetworkError.unauthorized
                }
                throw NetworkError.serverError(errorMessage)
            }
            
            print("✅ 预算状态获取成功")
            
            // 从API响应中提取数据
            guard let budgetData = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            
            // ✅ 更新当前预算和统计信息（确保在主线程）
            DispatchQueue.main.async {
                self?.currentBudget = budgetData.budget
                self?.currentStatistics = budgetData.statistics
            }
            
            if let budget = budgetData.budget {
                print("💰 当前预算: \(budget.formattedAmount)")
            } else {
                print("💰 未设置预算")
            }
            
            let stats = budgetData.statistics
            print("📊 支出统计: 已花费\(stats.formattedTotalExpenses), 使用率\(stats.usagePercentageString)")
            
            return ()
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                // ✅ 如果已经是NetworkError，直接返回（包括unauthorized）
                return networkError
            } else if let decodingError = error as? DecodingError {
                // ✅ DecodingError转换为decodingError
                print("❌ 预算数据解析失败: \(decodingError)")
                // 打印详细的解码错误信息
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ 缺少字段: \(key.stringValue), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("❌ 类型不匹配: 期望\(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("❌ 值不存在: 期望\(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("❌ 数据损坏: \(context.debugDescription)")
                @unknown default:
                    print("❌ 未知解码错误")
                }
                return NetworkError.decodingError(decodingError)
            } else {
                print("❌ 预算数据请求未知错误: \(error)")
                return NetworkError.unknown(error)
            }
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
     * 获取预算提醒和预警
     * GET /api/budget/alerts
     */
    func getBudgetAlerts() -> AnyPublisher<BudgetAlertsResponse, NetworkError> {
        print("⚠️ 获取预算提醒")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空提醒")
            let emptyResponse = BudgetAlertsResponse(alerts: [], summary: nil)
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetAlerts,
            method: .GET,
            
            responseType: APIResponse<BudgetAlertsResponse>.self
        )
        .tryMap { response in
            guard response.success else {
                let errorMessage = response.message ?? "获取预算提醒失败"
                print("❌ 获取预算提醒失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取到 \(data.alerts.count) 个预算提醒")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 获取预算建议
     * GET /api/budget/suggestions
     */
    func getBudgetSuggestions() -> AnyPublisher<BudgetSuggestionsResponse, NetworkError> {
        print("💡 获取预算建议")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空建议")
            let emptyResponse = BudgetSuggestionsResponse(suggestions: [], statistics: nil)
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetSuggestions,
            method: .GET,
            
            responseType: APIResponse<BudgetSuggestionsResponse>.self
        )
        .tryMap { response in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取到 \(data.suggestions.count) 个预算建议")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 获取预算历史记录
     * GET /api/budget/history
     */
    func getBudgetHistory() -> AnyPublisher<BudgetHistoryResponse, NetworkError> {
        print("📜 获取预算历史")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空历史")
            let emptyResponse = BudgetHistoryResponse(budgets: [])
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetHistory,
            method: .GET,
            
            responseType: APIResponse<BudgetHistoryResponse>.self
        )
        .tryMap { response in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取到 \(data.budgets.count) 条预算历史记录")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 获取指定月份预算
     * GET /api/budget/:year/:month
     */
    func getBudgetForMonth(year: Int, month: Int) -> AnyPublisher<BudgetMonthResponse, NetworkError> {
        print("📅 获取\(year)年\(month)月预算")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空预算")
            let emptyResponse = BudgetMonthResponse(budget: nil, totalExpenses: 0)
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetHistory,
            pathComponent: "\(year)/\(month)",
            method: .GET,
            responseType: APIResponse<BudgetMonthResponse>.self
        )
        .tryMap { response in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "BudgetService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取\(year)年\(month)月预算成功")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 删除指定预算
     * DELETE /api/budget/:budgetId
     */
    func deleteBudget(budgetId: String) -> AnyPublisher<Void, NetworkError> {
        print("🗑️ 删除预算: ID=\(budgetId)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法删除预算")
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .budgetHistory,
            pathComponent: budgetId,
            method: .DELETE,
            responseType: APIResponse<String>.self
        )
        .map { [weak self] _ in
            print("✅ 预算删除成功")
            
            // 如果删除的是当前预算，清空本地数据
            if self?.currentBudget?.id == budgetId {
                self?.currentBudget = nil
                self?.currentStatistics = nil
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
        // ✅ 修复：使用与NetworkManager一致的token key
        let token = UserDefaults.standard.string(forKey: "supabase_access_token")
        if let token = token {
            print("🔍 BudgetService获取Token成功")
        } else {
            print("🔍 BudgetService获取Token失败，key: supabase_access_token")
        }
        return token
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
