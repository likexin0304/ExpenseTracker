import Foundation
import Combine
import SwiftUI

/// 支出视图模型
class ExpenseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // 分页相关
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var hasMorePages = false
    @Published var isLoadingMore = false
    
    // 筛选条件
    @Published var selectedCategory: ExpenseCategory?
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var searchText = ""
    
    // 排序条件
    @Published var sortBy: SortOption = .date
    @Published var sortOrder: SortOrder = .descending
    
    // MARK: - Private Properties
    private let expenseService: ExpenseServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 20
    
    // MARK: - Enums
    enum SortOption: String, CaseIterable {
        case date = "date"
        case amount = "amount"
        case category = "category"
        
        var displayName: String {
            switch self {
            case .date: return "日期"
            case .amount: return "金额"
            case .category: return "分类"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
        
        var displayName: String {
            switch self {
            case .ascending: return "升序"
            case .descending: return "降序"
            }
        }
    }
    
    // MARK: - Initialization
    init(expenseService: ExpenseServiceProtocol = ExpenseService()) {
        self.expenseService = expenseService
        print("📊 ExpenseViewModel 初始化完成")
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("📊 ExpenseViewModel 已销毁")
    }
    
    // MARK: - Public Methods
    
    /// 加载支出列表
    func loadExpenses(refresh: Bool = false) {
        print("📋 加载支出列表: refresh=\(refresh)")
        
        if refresh {
            currentPage = 1
            hasMorePages = false
            isRefreshing = true
            // 不立即清空expenses，保持现有数据直到新数据到达
        }
        
        guard !isLoading else {
            print("⚠️ 正在加载中，跳过请求")
            return
        }
        
        isLoading = true
        errorMessage = nil
        showingError = false
        
        expenseService.getExpenses(
            page: currentPage,
            limit: pageSize,
            category: selectedCategory?.rawValue,
            startDate: startDate,
            endDate: endDate,
            sortBy: "date",
            sortOrder: "desc"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                self?.isLoadingMore = false
                self?.isRefreshing = false
                
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] data in
                self?.handleExpensesResponse(data, refresh: refresh)
            }
        )
        .store(in: &cancellables)
    }
    
    /// 加载更多支出记录
    func loadMoreExpenses() {
        guard !isLoading && !isLoadingMore && hasMorePages else {
            return
        }
        
        print("📄 加载更多支出记录: page=\(currentPage + 1)")
        
        isLoadingMore = true
        currentPage += 1
        
        expenseService.getExpenses(
            page: currentPage,
            limit: pageSize,
            category: selectedCategory?.rawValue,
            startDate: startDate,
            endDate: endDate,
            sortBy: "date",
            sortOrder: "desc"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
                
                if case .failure(let error) = completion {
                    self?.currentPage -= 1 // 回退页码
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] data in
                self?.handleExpensesResponse(data, refresh: false)
            }
        )
        .store(in: &cancellables)
    }
    
    /// 删除支出记录
    func deleteExpense(_ expense: Expense) {
        print("🗑️ 删除支出记录: ID=\(expense.id), 描述=\(expense.description)")
        print("🔍 完整ID长度: \(expense.id.count) 字符")
        
        // 验证ID格式
        guard !expense.id.isEmpty && expense.id.count > 10 else {
            print("❌ 无效的支出ID: \(expense.id)")
            errorMessage = "删除失败：无效的支出记录ID"
            showingError = true
            return
        }
        
        // 先调用API删除，成功后再更新UI（避免乐观更新导致的UI冲突）
        expenseService.deleteExpense(expenseId: expense.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ 支出删除失败: \(error)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    print("✅ 支出记录删除成功，开始更新UI")
                    
                    // 删除成功后，使用动画更新UI
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.expenses.removeAll { $0.id == expense.id }
                    }
                    
                    // 发送通知给其他页面（如预算页面）更新统计数据
                    NotificationCenter.default.post(
                        name: .expenseDataChanged,
                        object: nil,
                        userInfo: [
                            "operationType": "delete",
                            "skipRefresh": true // 跳过当前页面的刷新
                        ]
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    /// 应用筛选条件
    func applyFilters() {
        print("🔍 应用筛选条件")
        loadExpenses(refresh: true)
    }
    
    /// 清除筛选条件
    func clearFilters() {
        print("🧹 清除筛选条件")
        selectedCategory = nil
        startDate = nil
        endDate = nil
        searchText = ""
        loadExpenses(refresh: true)
    }
    
    /// 搜索支出记录
    func searchExpenses() {
        print("🔎 搜索支出记录: \(searchText)")
        loadExpenses(refresh: true)
    }
    
    // MARK: - Computed Properties
    
    /// 总支出金额
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// 格式化的总金额
    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "¥0.00"
    }
    
    /// 支出记录数量
    var expenseCount: Int {
        expenses.count
    }
    
    /// 按分类分组的支出记录
    var expensesByCategory: [String: [Expense]] {
        Dictionary(grouping: expenses) { $0.category }
    }
    
    /// 筛选后的支出记录
    var filteredExpenses: [Expense] {
        var filtered = expenses
        
        if !searchText.isEmpty {
            filtered = filtered.filter { expense in
                expense.description.localizedCaseInsensitiveContains(searchText) ||
                expense.category.localizedCaseInsensitiveContains(searchText) ||
                (expense.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    /// 是否有筛选条件
    var hasActiveFilters: Bool {
        selectedCategory != nil || startDate != nil || endDate != nil || !searchText.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// 处理支出列表响应
    private func handleExpensesResponse(_ data: ExpensesData, refresh: Bool) {
        if refresh || currentPage == 1 {
            expenses = data.expenses
        } else {
            expenses.append(contentsOf: data.expenses)
        }
        
        totalPages = data.pagination.pages
        hasMorePages = currentPage < data.pagination.pages
        
        print("✅ 支出列表加载成功: \(data.expenses.count) 条记录")
    }
    
    /// 处理错误
    private func handleError(_ error: NetworkError) {
        errorMessage = error.localizedDescription
        showingError = true
        print("❌ 支出操作失败: \(error)")
    }
    
    /// 设置通知监听
    private func setupNotificationObservers() {
        // 监听支出数据变化通知
        NotificationCenter.default.addObserver(
            forName: .expenseDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📢 ExpenseViewModel收到支出数据变化通知")
            if let operationType = notification.userInfo?["operationType"] as? String {
                print("📊 操作类型: \(operationType)")
                
                // 检查是否需要跳过刷新
                let skipRefresh = notification.userInfo?["skipRefresh"] as? Bool ?? false
                
                if !skipRefresh {
                    // 只有在不跳过刷新时才重新加载数据
                    self?.loadExpenses(refresh: true)
                } else {
                    print("🚫 跳过数据刷新，保持当前UI状态")
                }
            }
        }
    }
}
