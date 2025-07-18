import Foundation
import Combine

/// 支出服务协议
protocol ExpenseServiceProtocol {
    func createExpense(amount: Double, category: String, description: String, date: Date?, location: String?, paymentMethod: String, tags: [String]) -> AnyPublisher<Expense, NetworkError>
    func getExpenses(page: Int, limit: Int, category: String?, startDate: Date?, endDate: Date?, sortBy: String, sortOrder: String) -> AnyPublisher<ExpensesListResponse, NetworkError>
    func getExpenseCategories() -> AnyPublisher<[ExpenseCategory], NetworkError>
    func getExpenseStatistics(startDate: Date?, endDate: Date?, period: String) -> AnyPublisher<ExpenseStatsResponse, NetworkError>
    func updateExpense(expenseId: String, amount: Double?, category: String?, description: String?, date: Date?, location: String?, paymentMethod: String?, tags: [String]?) -> AnyPublisher<Expense, NetworkError>
    func deleteExpense(expenseId: String) -> AnyPublisher<Void, NetworkError>
}

/// 支出服务类 - 与API文档完全匹配
class ExpenseService: ObservableObject, ExpenseServiceProtocol {
    private let networkManager = NetworkManager.shared
    
    @Published var expenses: [Expense] = []
    @Published var categories: [ExpenseCategory] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    init() {
        print("💰 ExpenseService 初始化完成")
    }
    
    // MARK: - 创建支出记录
    /**
     * 创建新的支出记录
     * POST /api/expense
     */
    func createExpense(
        amount: Double,
        category: String,
        description: String,
        date: Date? = nil,
        location: String? = nil,
        paymentMethod: String = "cash",
        tags: [String] = []
    ) -> AnyPublisher<Expense, NetworkError> {
        
        print("💸 创建支出记录: ¥\(amount) - \(category)")
        
        guard amount > 0 else {
            return Fail(error: NetworkError.serverError("金额必须大于0"))
                .eraseToAnyPublisher()
        }
        
        guard !category.isEmpty && !description.isEmpty else {
            return Fail(error: NetworkError.serverError("分类和描述不能为空"))
                .eraseToAnyPublisher()
        }
        
        let request = CreateExpenseRequest(
            amount: amount,
            category: category,
            description: description,
            date: date,
            location: location,
            paymentMethod: paymentMethod,
            tags: tags
        )
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法添加支出")
            // 静默返回，不显示错误
            return Fail(error: NetworkError.serverError("请先登录"))
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .expense,
            method: .POST,
            body: request,
            responseType: APIResponse<Expense>.self
        )
        .tryMap { [weak self] response in
            guard response.success else {
                let errorMessage = response.message ?? "创建支出记录失败"
                print("❌ 创建支出记录失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            guard let expense = response.data else {
                throw NetworkError.decodingError(NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建支出响应数据为空"]))
            }
            
            print("✅ 支出记录创建成功: \(expense.formattedAmount)")
            
            // 添加到本地列表（在列表开头插入新记录）
            self?.expenses.insert(expense, at: 0)
            
            return expense
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                print("❌ 支出记录创建解析失败: \(error)")
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取支出记录列表
    /**
     * 获取支出记录列表
     * GET /api/expense
     */
    func getExpenses(
        page: Int = 1,
        limit: Int = 20,
        category: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        sortBy: String = "date",
        sortOrder: String = "desc"
    ) -> AnyPublisher<ExpensesListResponse, NetworkError> {
        
        print("📋 获取支出列表: page=\(page), limit=\(limit)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空支出列表")
            // 返回空列表，不显示错误
            let emptyResponse = ExpensesListResponse(
                expenses: [],
                pagination: ExpensePagination(
                    current: 1,
                    pages: 0,
                    total: 0,
                    limit: limit
                )
            )
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // 构建查询参数
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sortBy", value: sortBy),
            URLQueryItem(name: "sortOrder", value: sortOrder)
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        // 日期格式化
        let formatter = ISO8601DateFormatter()
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }
        
        
        return networkManager.request(
            endpoint: .expense,
            method: .GET,
            
            queryItems: queryItems,
            responseType: APIResponse<ExpensesListResponse>.self
        )
        .tryMap { [weak self] response -> ExpensesListResponse in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取支出列表响应数据为空"]))
            }
            
            print("✅ 获取到 \(data.expenses.count) 条支出记录")
            
            // 更新本地数据
            if page == 1 {
                self?.expenses = data.expenses
            } else {
                self?.expenses.append(contentsOf: data.expenses)
            }
            
            return data
        }
        .mapError { error -> NetworkError in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取支出分类列表
    /**
     * 获取支出分类列表
     * GET /api/expense/categories
     */
    func getExpenseCategories() -> AnyPublisher<[ExpenseCategory], NetworkError> {
        print("📂 获取支出分类列表")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空分类列表")
            // 返回空分类列表，不显示错误
            return Just([])
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        
        return networkManager.request(
            endpoint: .expenseCategories,
            method: .GET,
            
            responseType: APIResponse<ExpenseCategoriesResponse>.self
        )
        .tryMap { [weak self] response -> [ExpenseCategory] in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取分类响应数据为空"]))
            }
            
            print("✅ 获取到 \(data.categories.count) 个分类")
            
            // 更新本地分类数据
            self?.categories = data.categories
            
            return data.categories
        }
        .mapError { error -> NetworkError in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取支出统计
    /**
     * 获取支出统计信息
     * GET /api/expense/stats
     */
    func getExpenseStatistics(
        startDate: Date? = nil,
        endDate: Date? = nil,
        period: String = "month"
    ) -> AnyPublisher<ExpenseStatsResponse, NetworkError> {
        
        print("📊 获取支出统计: period=\(period)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空统计数据")
            // 返回空统计数据，不显示错误
            let emptyStats = ExpenseStatsResponse(
                categoryStats: [],
                totalStats: TotalStat(
                    totalAmount: 0,
                    totalCount: 0,
                    avgAmount: 0,
                    maxAmount: 0,
                    minAmount: 0
                ),
                periodStats: []
            )
            return Just(emptyStats)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // 构建查询参数
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "period", value: period)
        ]
        
        let formatter = ISO8601DateFormatter()
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }
        
        
        return networkManager.request(
            endpoint: .expenseStats,
            method: .GET,
            
            queryItems: queryItems,
            responseType: APIResponse<ExpenseStatsResponse>.self
        )
        .tryMap { response -> ExpenseStatsResponse in
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取统计响应数据为空"]))
            }
            print("✅ 获取统计成功: 总支出 \(data.totalStats.formattedTotalAmount)")
            return data
        }
        .mapError { error -> NetworkError in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 更新支出记录
    /**
     * 更新支出记录
     * PUT /api/expense/:id
     */
    func updateExpense(
        expenseId: String,
        amount: Double? = nil,
        category: String? = nil,
        description: String? = nil,
        date: Date? = nil,
        location: String? = nil,
        paymentMethod: String? = nil,
        tags: [String]? = nil
    ) -> AnyPublisher<Expense, NetworkError> {
        
        print("✏️ 更新支出记录: ID=\(expenseId)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法更新支出")
            return Fail(error: NetworkError.serverError("请先登录"))
                .eraseToAnyPublisher()
        }
        
        // 构建更新请求体（使用UpdateExpenseRequest）
        let updateRequest = UpdateExpenseRequest(
            amount: amount,
            category: category,
            description: description,
            date: date,
            location: location,
            paymentMethod: paymentMethod,
            tags: tags
        )
        
        
        return networkManager.request(
            endpoint: .expense,
            pathComponent: expenseId,
            method: .PUT,
            body: updateRequest,
            responseType: APIResponse<Expense>.self
        )
        .tryMap { [weak self] response in
            guard response.success else {
                let errorMessage = response.message ?? "更新支出记录失败"
                print("❌ 更新支出记录失败: \(errorMessage)")
                throw NetworkError.serverError(errorMessage)
            }
            
            guard let updatedExpense = response.data else {
                throw NetworkError.decodingError(NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "更新支出响应数据为空"]))
            }
            
            print("✅ 支出记录更新成功")
            
            // 更新本地列表中的对应记录
            if let index = self?.expenses.firstIndex(where: { $0.id == expenseId }) {
                self?.expenses[index] = updatedExpense
            }
            
            return updatedExpense
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                print("❌ 支出记录更新解析失败: \(error)")
                return NetworkError.decodingError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 删除支出记录
    /**
     * 删除支出记录
     * DELETE /api/expense/:id
     */
    func deleteExpense(expenseId: String) -> AnyPublisher<Void, NetworkError> {
        print("🗑️ ExpenseService.deleteExpense: ID=\(expenseId)")
        print("🔍 ID长度: \(expenseId.count) 字符")
        print("🔍 ID前10字符: \(String(expenseId.prefix(10)))")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法删除支出")
            return Fail(error: NetworkError.serverError("请先登录"))
                .eraseToAnyPublisher()
        }
        
        // 🔥 修复：直接使用UUID作为路径参数，符合后端API文档要求
        // 后端API文档明确要求: DELETE /api/expense/:id 格式
        let endpoint = "/expense/\(expenseId)"
        
        print("🌐 删除请求URL: \(endpoint)")
        print("📋 UUID格式验证: \(expenseId)")
        
        
        return networkManager.request(
            endpoint: .expense,
            pathComponent: expenseId,
            method: .DELETE,
            responseType: APIResponse<EmptyResponse>.self
        )
        .map { [weak self] _ in
            print("✅ 支出删除成功")
            
            // 从本地列表中移除对应记录
            self?.expenses.removeAll { $0.id == expenseId }
            
            // 发送删除成功通知
            NotificationCenter.default.post(
                name: .expenseDeleted,
                object: nil,
                userInfo: ["expenseId": expenseId, "skipRefresh": true]
            )
        }
        .mapError { error in
            print("❌ 支出删除失败: \(error)")
            return error
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 便捷方法
    
    /**
     * 刷新支出数据
     */
    func refreshExpenses() {
        isLoading = true
        errorMessage = ""
        
        getExpenses()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("❌ 刷新支出数据失败: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 支出数据刷新成功")
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * 加载分类数据
     */
    func loadCategories() {
        getExpenseCategories()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 加载分类失败: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ 分类数据加载成功")
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * 清空数据（用于登出）
     */
    func clearData() {
        expenses.removeAll()
        categories.removeAll()
        isLoading = false
        errorMessage = ""
    }
    
    // MARK: - 私有方法
    
    /**
     * 获取认证Token
     */
    private func getAuthToken() -> String? {
        // ✅ 修复：使用与NetworkManager一致的token key
        let token = UserDefaults.standard.string(forKey: "supabase_access_token")
        if let token = token {
            print("🔍 ExpenseService获取Token成功")
        } else {
            print("🔍 ExpenseService获取Token失败，key: supabase_access_token")
        }
        return token
    }
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - 新增API端点

extension ExpenseService {
    /**
     * 导出支出数据
     * GET /api/expense/export
     */
    func exportExpenses(
        format: String = "json",
        startDate: Date? = nil,
        endDate: Date? = nil,
        category: String? = nil,
        download: Bool = false
    ) -> AnyPublisher<ExpenseExportResponse, NetworkError> {
        print("📤 导出支出数据: format=\(format)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，无法导出数据")
            return Fail(error: NetworkError.serverError("请先登录"))
                .eraseToAnyPublisher()
        }
        
        // 构建查询参数
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "format", value: format),
            URLQueryItem(name: "download", value: download ? "true" : "false")
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        // 日期格式化
        let formatter = ISO8601DateFormatter()
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }
        
        
        return networkManager.request(
            endpoint: .expenseExport,
            method: .GET,
            
            queryItems: queryItems,
            responseType: APIResponse<ExpenseExportResponse>.self
        )
        .tryMap { response -> ExpenseExportResponse in
            guard response.success, let data = response.data else {
                throw NetworkError.serverError(response.message ?? "导出失败")
            }
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * 获取支出趋势分析
     * GET /api/expense/trends
     */
    func getExpenseTrends(
        period: String = "month",
        limit: Int = 12
    ) -> AnyPublisher<ExpenseTrendsResponse, NetworkError> {
        print("📈 获取支出趋势: period=\(period), limit=\(limit)")
        
        guard let token = getAuthToken() else {
            print("⚠️ 用户未登录，返回空趋势数据")
            let emptyResponse = ExpenseTrendsResponse(
                period: period,
                trends: [],
                analysis: nil
            )
            return Just(emptyResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        // 构建查询参数
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        
        return networkManager.request(
            endpoint: .expenseTrends,
            method: .GET,
            
            queryItems: queryItems,
            responseType: APIResponse<ExpenseTrendsResponse>.self
        )
        .tryMap { response -> ExpenseTrendsResponse in
            guard response.success, let data = response.data else {
                throw NetworkError.serverError(response.message ?? "获取趋势失败")
            }
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.unknown(error)
            }
        }
        .eraseToAnyPublisher()
    }
}

// EmptyResponse已在BudgetService.swift中定义
