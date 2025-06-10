import Foundation
import Combine
import SwiftUI

/**
 * 预算视图模型
 * 连接预算服务和UI界面，处理用户交互和数据绑定
 */
class BudgetViewModel: ObservableObject {
    // MARK: - 发布属性（UI绑定）
    
    /// 当前预算信息
    @Published var currentBudget: Budget?
    
    /// 预算统计信息
    @Published var statistics: BudgetStatistics?
    
    /// 加载状态
    @Published var isLoading = false
    
    /// 错误消息
    @Published var errorMessage = ""
    
    /// 是否显示错误提示
    @Published var showError = false
    
    /// 预算输入金额（用于设置预算界面）
    @Published var budgetInput = ""
    
    /// 是否显示设置预算弹窗
    @Published var showSetBudgetSheet = false
    
    /// 是否显示预算详情
    @Published var showBudgetDetails = false
    
    // MARK: - 私有属性
    private let budgetService = BudgetService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        print("🎯 BudgetViewModel初始化")
        setupBindings()
        loadBudgetData()
    }
    
    // MARK: - 数据绑定设置
    
    /**
     * 设置数据绑定
     * 监听BudgetService的数据变化并更新ViewModel
     */
    private func setupBindings() {
        // 监听预算数据变化
        budgetService.$currentBudget
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentBudget, on: self)
            .store(in: &cancellables)
        
        // 监听统计数据变化
        budgetService.$currentStatistics
            .receive(on: DispatchQueue.main)
            .assign(to: \.statistics, on: self)
            .store(in: &cancellables)
        
        // 监听加载状态
        budgetService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // 监听错误消息
        budgetService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.showError = !message.isEmpty
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /**
     * 加载预算数据
     * 应用启动或刷新时调用
     */
    func loadBudgetData() {
        print("📊 开始加载预算数据")
        isLoading = true
        errorMessage = ""
        
        budgetService.getCurrentBudgetStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ 加载预算数据失败: \(error.localizedDescription)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    print("✅ 预算数据加载成功")
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * 设置预算
     * 根据用户输入设置新的预算金额
     */
    func setBudget() {
        print("💰 开始设置预算: \(budgetInput)")
        
        // 输入验证
        guard !budgetInput.isEmpty else {
            showErrorMessage("请输入预算金额")
            return
        }
        
        guard let amount = Double(budgetInput), amount > 0 else {
            showErrorMessage("请输入有效的预算金额")
            return
        }
        
        if amount > 1000000 {
            showErrorMessage("预算金额不能超过100万元")
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        budgetService.setBudget(amount: amount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ 设置预算失败: \(error.localizedDescription)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    print("✅ 预算设置成功")
                    self?.isLoading = false
                    self?.showSetBudgetSheet = false
                    self?.budgetInput = ""
                    self?.showSuccessMessage("预算设置成功")
                }
            )
            .store(in: &cancellables)
    }
    
    /**
     * 刷新预算数据
     * 下拉刷新时调用
     */
    func refreshBudget() {
        print("🔄 刷新预算数据")
        loadBudgetData()
    }
    
    /**
     * 显示设置预算界面
     */
    func showSetBudget() {
        print("📝 显示设置预算界面")
        budgetInput = currentBudget?.amount.description ?? ""
        showSetBudgetSheet = true
    }
    
    /**
     * 删除当前预算
     */
    func deleteBudget() {
        print("🗑️ 删除当前预算")
        
        guard currentBudget != nil else {
            showErrorMessage("没有预算可删除")
            return
        }
        
        isLoading = true
        
        budgetService.deleteBudget()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ 删除预算失败: \(error.localizedDescription)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    print("✅ 预算删除成功")
                    self?.isLoading = false
                    self?.showSuccessMessage("预算已删除")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 计算属性（UI显示用）
    
    /**
     * 是否已设置预算
     */
    var hasBudget: Bool {
        return currentBudget != nil
    }
    
    /**
     * 格式化的预算金额
     */
    var formattedBudgetAmount: String {
        return currentBudget?.formattedAmount ?? "¥0"
    }
    
    /**
     * 格式化的已花费金额
     */
    var formattedExpensesAmount: String {
        return statistics?.formattedTotalExpenses ?? "¥0"
    }
    
    /**
     * 格式化的剩余预算
     */
    var formattedRemainingBudget: String {
        return statistics?.formattedRemainingBudget ?? "¥0"
    }
    
    /**
     * 预算使用进度 (0.0 - 1.0)
     */
    var usageProgress: Double {
        return statistics?.usageProgress ?? 0.0
    }
    
    /**
     * 使用百分比字符串
     */
    var usagePercentageString: String {
        return statistics?.usagePercentageString ?? "0%"
    }
    
    /**
     * 是否超支
     */
    var isOverBudget: Bool {
        return statistics?.isOverBudget ?? false
    }
    
    /**
     * 预算状态颜色
     */
    var statusColor: Color {
        guard let stats = statistics else { return .gray }
        
        switch stats.statusColor {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "green":
            return .green
        default:
            return .gray
        }
    }
    
    /**
     * 预算状态描述
     */
    var statusDescription: String {
        return statistics?.statusDescription ?? "未设置预算"
    }
    
    /**
     * 预算建议
     */
    var budgetSuggestion: String {
        return statistics?.suggestion ?? "建议设置月度预算来管理支出"
    }
    
    /**
     * 月份显示字符串
     */
    var monthDisplayString: String {
        if let budget = currentBudget {
            return budget.monthDisplayString
        } else {
            let now = Date()
            let calendar = Calendar.current
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            return "\(year)年\(month)月"
        }
    }
    
    // MARK: - 输入验证方法
    
    /**
     * 验证预算输入是否有效
     */
    var isBudgetInputValid: Bool {
        guard !budgetInput.isEmpty,
              let amount = Double(budgetInput),
              amount > 0,
              amount <= 1000000 else {
            return false
        }
        return true
    }
    
    /**
     * 获取预算输入错误提示
     */
    var budgetInputErrorMessage: String {
        if budgetInput.isEmpty {
            return ""
        }
        
        guard let amount = Double(budgetInput) else {
            return "请输入有效的数字"
        }
        
        if amount <= 0 {
            return "预算金额必须大于0"
        }
        
        if amount > 1000000 {
            return "预算金额不能超过100万"
        }
        
        return ""
    }
    
    // MARK: - 私有辅助方法
    
    /**
     * 处理错误
     */
    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        showErrorMessage(message)
    }
    
    /**
     * 显示错误消息
     */
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // 3秒后自动隐藏错误消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showError = false
            self?.errorMessage = ""
        }
    }
    
    /**
     * 显示成功消息
     */
    private func showSuccessMessage(_ message: String) {
        // 这里可以实现成功提示的显示逻辑
        print("✅ \(message)")
        
        // 可以使用HUD或者Toast来显示成功消息
        // 暂时使用print，后续可以添加UI提示组件
    }
    
    /**
     * 清除数据
     * 用户登出时调用
     */
    func clearData() {
        print("🧹 清除预算ViewModel数据")
        currentBudget = nil
        statistics = nil
        isLoading = false
        errorMessage = ""
        showError = false
        budgetInput = ""
        showSetBudgetSheet = false
        showBudgetDetails = false
        
        // 清除服务层数据
        budgetService.clearBudgetData()
    }
}

// MARK: - BudgetViewModel扩展 - 格式化方法
extension BudgetViewModel {
    /**
     * 格式化货币（通用方法）
     */
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0 // 不显示小数点
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
    
    /**
     * 格式化百分比
     */
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
    
    /**
     * 获取预算剩余天数描述
     */
    var remainingDaysInMonth: String {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取当月最后一天
        guard let range = calendar.range(of: .day, in: .month, for: now) else {
            return ""
        }
        
        let currentDay = calendar.component(.day, from: now)
        let totalDays = range.count
        let remainingDays = totalDays - currentDay + 1
        
        return "本月还剩 \(remainingDays) 天"
    }
    
    /**
     * 获取平均每日可用预算
     */
    var averageDailyBudget: String {
        guard let stats = statistics,
              stats.budgetAmount > 0,
              stats.remainingBudget > 0 else {
            return "¥0"
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        
        // 获取当月总天数
        guard let range = calendar.range(of: .day, in: .month, for: now) else {
            return "¥0"
        }
        
        let totalDays = range.count
        let remainingDays = totalDays - currentDay + 1
        
        if remainingDays <= 0 {
            return "¥0"
        }
        
        let dailyBudget = stats.remainingBudget / Double(remainingDays)
        return formatCurrency(dailyBudget)
    }
}
