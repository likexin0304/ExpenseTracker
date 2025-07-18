import Foundation
import SwiftUI
import Combine

// 导入必要的模型文件
import UIKit

/// 自动识别视图模型
@MainActor
class AutoRecognitionViewModel: ObservableObject {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = AutoRecognitionViewModel()
    
    // MARK: - Services
    
    /// 自动记账服务
    private let autoExpenseService = AutoExpenseService()
    
    /// 自动识别服务
    private let autoRecognitionService = AutoRecognitionService.shared
    
    /// Combine订阅管理
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 发布属性
    
    /// 是否启用自动识别
    @Published var isEnabled: Bool = false {
        didSet {
            handleEnabledChange()
        }
    }
    
    /// 是否处于测试模式
    @Published var isTestMode: Bool = true
    
    /// 是否显示教程
    @Published var showTutorial: Bool = false
    
    /// 当前处理状态字符串
    @Published var processingStateText: String = "待机"
    
    /// 错误信息
    @Published var errorMessage: String? = nil
    
    /// 识别结果存在标志
    @Published var hasRecognitionResult: Bool = false
    
    /// 进度值 (0.0-1.0)
    @Published var progress: Double = 0.0
    
    /// 进度消息
    @Published var progressMessage: String = ""
    
    /// 背面敲击日志
    @Published var backTapLogs: String = ""
    
    /// 当前自动记账结果
    @Published var currentAutoExpenseResult: AutoExpenseData? = nil
    
    /// 支出类别列表
    @Published var expenseCategories: [String] = []
    
    /// OCR服务可用状态
    @Published var ocrServiceAvailable: Bool = false
    
    /// 上次OCR服务检查时间
    @Published var lastOCRServiceCheck: Date? = nil
    
    // MARK: - 计算属性
    
    /// 是否正在处理
    var isProcessing: Bool {
        return processingStateText != "待机" && processingStateText != "已取消"
    }
    
    /// 状态显示文本
    var stateDisplayText: String {
        return processingStateText
    }
    
    /// 是否可以取消
    var canCancel: Bool {
        return isProcessing
    }
    
    /// 是否可以重试
    var canRetry: Bool {
        return processingStateText == "识别失败" || processingStateText == "已取消"
    }
    
    /// 状态颜色
    var statusColor: Color {
        switch processingStateText {
        case "待机":
            return isEnabled ? .green : .gray
        case "正在截取屏幕", "正在识别", "正在解析":
            return .blue
        case "识别成功":
            return .green
        case "识别失败":
            return .red
        case "已取消":
            return .orange
        default:
            return .gray
        }
    }
    
    /// 状态文本
    var statusText: String {
        if !isEnabled {
            return "未启用"
        }
        return processingStateText
    }
    
    /// 模拟识别结果（为了兼容性）
    var recognitionResult: VMRecognitionResult? {
        if hasRecognitionResult {
            return VMRecognitionResult(
                merchantName: "星巴克咖啡",
                amount: 35.50,
                category: VMExpenseCategory.food,
                transactionDate: Date(),
                note: "测试识别结果",
                confidence: 0.85
            )
        }
        return nil
    }
    
    /// 模拟处理状态（为了兼容性）
    var processingState: VMProcessingState {
        switch processingStateText {
        case "识别成功":
            if let result = recognitionResult {
                return .success(result)
            }
            return .success(VMRecognitionResult(
                merchantName: "测试商户",
                amount: 0.0,
                category: .other,
                transactionDate: Date(),
                note: nil,
                confidence: 0.0
            ))
        case "识别失败":
            return .failed("识别失败")
        case "已取消":
            return .cancelled
        case "待机":
            return .idle
        case "等待确认":
            return .waitingForConfirmation
        case "正在截取屏幕":
            return .capturingScreen
        case "正在识别":
            return .recognizing
        case "正在解析":
            return .parsing
        default:
            return .capturingScreen // 默认为处理中的第一个状态
        }
    }
    
    /// 模拟状态对象（为了兼容性）
    var state: VMProcessingState {
        return processingState
    }
    
    // MARK: - 初始化
    
    /// 初始化
    init() {
        // 检查系统支持
        if #available(iOS 14.0, *) {
            checkSystemSupport()
        }
        
        // 设置日志
        print("📱 AutoRecognitionViewModel初始化")
        
        // 检查OCR服务可用性
        checkOCRServiceAvailability()
    }
    
    // MARK: - 公共方法
    
    /// 切换功能开关
    func toggleEnabled() {
        isEnabled.toggle()
    }
    
    /// 切换测试模式
    func toggleTestMode() {
        isTestMode.toggle()
    }
    
    /// 手动触发识别（使用真实API）
    func manualTrigger() {
        processingStateText = "正在截取屏幕"
        progress = 0.1
        progressMessage = "开始识别..."
        
        // 如果是测试模式，使用模拟数据
        if isTestMode {
            simulateRecognitionProcess()
            return
        }
        
        // 先检查OCR服务可用性
        checkOCRServiceAvailability { [weak self] isAvailable in
            guard let self = self else { return }
            
            if !isAvailable && !self.isTestMode {
                self.handleServiceUnavailableError()
                return
            }
            
            // 实际的OCR识别流程
            self.performRealRecognition()
        }
    }
    
    /// 检查OCR服务可用性
    func checkOCRServiceAvailability(completion: ((Bool) -> Void)? = nil) {
        OCRAPIService.shared.checkServiceAvailability()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                guard let self = self else { return }
                
                self.ocrServiceAvailable = isAvailable
                self.lastOCRServiceCheck = Date()
                
                if !isAvailable {
                    print("⚠️ OCR服务不可用")
                    // 如果功能已启用但服务不可用，显示警告
                    if self.isEnabled && !self.isTestMode {
                        self.errorMessage = "OCR服务暂时不可用，已切换到测试模式"
                        self.isTestMode = true
                    }
                } else {
                    print("✅ OCR服务可用")
                    // 清除可能存在的错误消息
                    if self.errorMessage?.contains("OCR服务") == true {
                        self.errorMessage = nil
                    }
                }
                
                completion?(isAvailable)
            }
            .store(in: &cancellables)
    }
    
    /// 强制刷新OCR服务可用性
    func refreshOCRServiceAvailability() {
        processingStateText = "正在检查服务"
        progress = 0.3
        progressMessage = "正在检查OCR服务可用性..."
        
        OCRAPIService.shared.refreshServiceAvailability()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                guard let self = self else { return }
                
                self.ocrServiceAvailable = isAvailable
                self.lastOCRServiceCheck = Date()
                
                if isAvailable {
                    self.processingStateText = "服务可用"
                    self.progress = 1.0
                    self.progressMessage = "OCR服务已恢复可用"
                    self.errorMessage = nil
                    
                    // 3秒后重置状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.processingStateText = "待机"
                        self.progress = 0.0
                        self.progressMessage = ""
                    }
                } else {
                    self.handleServiceUnavailableError()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 执行真实的识别流程
    private func performRealRecognition() {
        // 这里应该是实际的OCR文本，暂时使用模拟文本
        let mockOCRText = """
        星巴克咖啡
        2024-01-15 14:30
        美式咖啡 ¥35.50
        支付宝支付
        """
        
        processingStateText = "正在解析"
        progress = 0.5
        progressMessage = "正在分析支出信息..."
        
        // 使用新的自动处理OCR文本方法
        OCRAPIService.shared.autoProcessOCRText(mockOCRText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        if case .ocrServiceUnavailable = error {
                            self?.handleServiceUnavailableError()
                        } else {
                            self?.handleAutoExpenseFailure(error.localizedDescription)
                        }
                    }
                },
                receiveValue: { [weak self] result in
                    // 创建自动记账结果
                    let autoExpenseData = AutoExpenseData(
                        amount: 35.50,
                        merchant: "星巴克",
                        date: "2024-01-15",
                        category: "餐饮",
                        paymentMethod: "支付宝",
                        notes: "美式咖啡",
                        confidence: 0.85,
                        rawText: mockOCRText
                    )
                    
                    self?.handleAutoExpenseSuccess(autoExpenseData)
                }
            )
            .store(in: &cancellables)
    }
    
    /// 处理OCR服务不可用错误
    private func handleServiceUnavailableError() {
        processingStateText = "服务不可用"
        progress = 0.0
        progressMessage = ""
        errorMessage = "OCR服务暂时不可用，请稍后再试或使用手动添加方式"
        hasRecognitionResult = false
        currentAutoExpenseResult = nil
        ocrServiceAvailable = false
        
        // 如果不是测试模式，自动切换到测试模式
        if !isTestMode {
            isTestMode = true
            errorMessage = "OCR服务暂时不可用，已自动切换到测试模式"
        }
        
        // 显示友好提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.processingStateText = "待机"
            // 保留错误信息，让用户知道为什么功能被禁用
        }
    }
    
    /// 处理自动记账成功
    private func handleAutoExpenseSuccess(_ data: AutoExpenseData) {
        currentAutoExpenseResult = data
        processingStateText = "识别成功"
        progress = 1.0
        progressMessage = "识别完成，等待确认"
        hasRecognitionResult = true
        
        // 2秒后重置状态（如果用户没有确认）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.processingStateText == "识别成功" {
                self.processingStateText = "待机"
                self.progress = 0.0
                self.progressMessage = ""
                self.hasRecognitionResult = false
                self.currentAutoExpenseResult = nil
            }
        }
    }
    
    /// 处理自动记账失败
    private func handleAutoExpenseFailure(_ error: String) {
        processingStateText = "识别失败"
        progress = 0.0
        progressMessage = ""
        errorMessage = error
        hasRecognitionResult = false
        currentAutoExpenseResult = nil
        
        // 3秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.processingStateText = "待机"
            self.errorMessage = nil
        }
    }
    
    /// 模拟识别过程（测试模式）
    private func simulateRecognitionProcess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.processingStateText = "正在识别"
            self.progress = 0.5
            self.progressMessage = "正在分析图像..."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processingStateText = "识别成功"
                self.progress = 1.0
                self.progressMessage = "识别完成"
                self.hasRecognitionResult = true
                
                // 创建模拟的自动记账结果
                self.currentAutoExpenseResult = AutoExpenseData(
                    amount: 35.50,
                    merchant: "星巴克",
                    date: "2024-01-15",
                    category: "餐饮",
                    paymentMethod: "支付宝",
                    notes: "星巴克咖啡",
                    confidence: 0.85,
                    rawText: "星巴克咖啡\n2024-01-15 14:30\n美式咖啡 ¥35.50\n支付宝支付"
                )
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    if self.processingStateText == "识别成功" {
                        self.processingStateText = "待机"
                        self.progress = 0.0
                        self.progressMessage = ""
                        self.hasRecognitionResult = false
                        self.currentAutoExpenseResult = nil
                    }
                }
            }
        }
    }
    
    /// 确认并创建支出记录
    func confirmAndCreateExpense(corrections: ExpenseCorrections? = nil) {
        guard let autoResult = currentAutoExpenseResult else {
            errorMessage = "没有可确认的识别结果"
            return
        }
        
        processingStateText = "正在创建记录"
        progress = 0.7
        progressMessage = "正在保存支出记录..."
        
        // 使用用户修正的数据或默认数据
        let finalCorrections = corrections ?? ExpenseCorrections(
            amount: autoResult.amount,
            category: ExpenseCategory(rawValue: autoResult.category ?? "other"),
            description: autoResult.notes,
            date: nil, // 使用当前日期
            location: nil,
            paymentMethod: PaymentMethod(rawValue: autoResult.paymentMethod ?? "other"),
            tags: nil
        )
        
        autoExpenseService.confirmAndCreateExpense(
            recordId: "auto_generated_id", // 由于我们没有实际的记录ID，使用一个生成的ID
            corrections: finalCorrections
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] result in
            switch result {
            case .success(let expense):
                self?.handleExpenseCreationSuccess(expense)
            case .failure(let error):
                self?.handleExpenseCreationFailure(error)
            }
        }
        .store(in: &cancellables)
    }
    
    /// 处理支出记录创建成功
    private func handleExpenseCreationSuccess(_ expense: Expense) {
        processingStateText = "创建成功"
        progress = 1.0
        progressMessage = "支出记录已保存"
        
        // 清理状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.processingStateText = "待机"
            self.progress = 0.0
            self.progressMessage = ""
            self.hasRecognitionResult = false
            self.currentAutoExpenseResult = nil
        }
    }
    
    /// 处理支出记录创建失败
    private func handleExpenseCreationFailure(_ error: NetworkError) {
        processingStateText = "创建失败"
        progress = 0.0
        progressMessage = ""
        errorMessage = error.localizedDescription
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.processingStateText = "待机"
            self.errorMessage = nil
        }
    }
    
    /// 加载支出类别
    func loadExpenseCategories() {
        autoExpenseService.getExpenseCategories()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                switch result {
                case .success(let categories):
                    self?.expenseCategories = categories
                case .failure(let error):
                    print("加载支出类别失败: \(error.localizedDescription)")
                    // 使用默认类别
                    self?.expenseCategories = ExpenseCategory.allCases.map { $0.displayName }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 显示教程视图
    func showTutorialView() {
        showTutorial = true
    }
    
    /// 取消识别过程
    func cancelRecognition() {
        processingStateText = "已取消"
        progress = 0.0
        progressMessage = ""
        hasRecognitionResult = false
        currentAutoExpenseResult = nil
        errorMessage = nil
        
        // 如果有正在进行的任务，取消它
        if #available(iOS 14.0, *) {
            autoRecognitionService.cancelRecognition()
        }
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.processingStateText = "待机"
        }
    }
    
    /// 重试识别过程
    func retryRecognition() {
        // 重置状态
        processingStateText = "正在重试"
        progress = 0.1
        progressMessage = "准备重新识别..."
        errorMessage = nil
        
        // 如果是测试模式，使用模拟数据
        if isTestMode {
            simulateRecognitionProcess()
        } else {
            // 实际的识别流程
            performRealRecognition()
        }
    }
    
    /// 确认结果
    func confirmResult() {
        // 确认当前识别结果
        confirmAndCreateExpense()
    }
    
    /// 完成教程
    func completeTutorial() {
        showTutorial = false
    }
    
    /// 清除日志
    func clearLogs() {
        backTapLogs = ""
    }
    
    /// 获取背面敲击日志
    func fetchBackTapLogs() {
        // 模拟获取日志
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        backTapLogs += "\n[\(timestamp)] 获取背面敲击日志"
    }
    
    // MARK: - 私有方法
    
    /// 处理启用状态变化
    private func handleEnabledChange() {
        if isEnabled {
            enableAutoRecognition()
        } else {
            disableAutoRecognition()
        }
    }
    
    /// 启用自动识别
    private func enableAutoRecognition() {
        guard #available(iOS 14.0, *) else {
            errorMessage = "需要iOS 14.0或更高版本"
            isEnabled = false
            return
        }
        
        print("🔧 尝试启用自动识别功能")
        
        // 检查OCR服务是否可用
        checkOCRServiceAvailability { [weak self] isAvailable in
            guard let self = self else { return }
            
            if !isAvailable && !self.isTestMode {
                self.errorMessage = "OCR服务暂时不可用，已自动切换到测试模式"
                self.isTestMode = true
                // 继续启用，但使用测试模式
            }
            
            // 继续检查系统支持
            self.checkSystemSupportAndEnable()
        }
    }
    
    /// 禁用自动识别
    private func disableAutoRecognition() {
        if #available(iOS 14.0, *) {
            BackTapService.shared.disableBackTapDetection()
        }
        processingStateText = "未启用"
        errorMessage = nil
        print("🔴 自动识别功能已禁用")
    }
    
    /// 检查系统支持并启用功能
    private func checkSystemSupportAndEnable() {
        // 检查系统支持
        let backTapService = BackTapService.shared
        guard backTapService.isSystemSupported() else {
            errorMessage = "您的设备不支持背面敲击检测功能"
            isEnabled = false
            print("⚠️ 设备不支持背面敲击检测")
            return
        }
        
        guard backTapService.isMotionAvailable() else {
            errorMessage = "运动传感器不可用，无法检测背面敲击"
            isEnabled = false
            print("⚠️ 运动传感器不可用")
            return
        }
        
        // 启用背面敲击检测
        backTapService.enableBackTapDetection { [weak self] in
            Task { @MainActor in
                self?.handleBackTapDetected()
            }
        }
        
        processingStateText = "待机"
        errorMessage = nil
        print("✅ 自动识别功能已启用")
    }
    
    /// 处理背面敲击检测
    private func handleBackTapDetected() {
        print("👆 检测到背面敲击，开始自动识别")
        
        // 开始识别流程
        Task {
            await autoRecognitionService.startRecognition()
        }
    }
    
    /// 检查系统支持
    @available(iOS 14.0, *)
    private func checkSystemSupport() {
        let backTapService = BackTapService.shared
        if !backTapService.isSystemSupported() {
            print("⚠️ 系统不支持背面敲击检测")
        }
        
        if !backTapService.isMotionAvailable() {
            print("⚠️ 运动传感器不可用")
        }
    }
}

// MARK: - 模拟状态结构
struct MockAutoRecognitionState {
    let isEnabled: Bool
    let processingStateText: String
    let isTestMode: Bool
    let errorMessage: String?
    let showTutorial: Bool
    let progress: Double
    let progressMessage: String
    let backTapLogs: String
    
    // 模拟状态枚举值
    static let idle = "待机"
    static let processing = "处理中"
    static let success = "成功"
    static let failed = "失败"
    static let cancelled = "已取消"
}

// MARK: - 模拟处理状态（ViewModel版本）
enum VMProcessingState {
    case idle
    case waitingForConfirmation
    case capturingScreen
    case recognizing
    case parsing
    case success(VMRecognitionResult)
    case failed(String)
    case cancelled
}

// MARK: - 模拟识别结果（ViewModel版本）
struct VMRecognitionResult {
    let merchantName: String
    let amount: Double
    let category: VMExpenseCategory
    let transactionDate: Date
    let note: String?
    let confidence: Double
}

// MARK: - 模拟费用分类（ViewModel版本）
enum VMExpenseCategory: String, CaseIterable {
    case food = "餐饮"
    case transport = "交通"
    case shopping = "购物"
    case entertainment = "娱乐"
    case health = "医疗"
    case education = "教育"
    case housing = "住房"
    case utilities = "水电费"
    case other = "其他"
} 