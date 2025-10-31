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
    
    /// 是否显示确认界面
    @Published var showConfirmationView: Bool = false
    
    /// 当前OCR记录的ID（用于确认时创建支出）
    @Published var currentRecordId: String? = nil
    
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
    /// - Note: 此方法用于真实的背敲或URL Scheme触发场景，始终使用真实OCR流程
    func manualTrigger() {
        print("🚀 manualTrigger() 被调用")
        
        // ✅ 手动触发始终使用真实OCR流程（忽略测试模式标志）
        // 测试模式只用于UI上的手动测试，不应该影响自动触发的真实场景
        print("✅ 使用真实OCR流程（忽略测试模式标志）")
        
        // ✅ 步骤0: 检查屏幕录制权限
        Task { @MainActor in
            processingStateText = "正在检查权限"
            progress = 0.05
            progressMessage = "正在检查屏幕录制权限..."
        }
        
        Task {
            // 检查权限状态
            ScreenCaptureService.shared.checkPermissionStatus()
            
            // 等待一小段时间让权限检查完成
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            
            // ✅ 在主线程访问@Published属性
            let hasPermission = await MainActor.run {
                ScreenCaptureService.shared.permissionStatus == .authorized
            }
            
            if !hasPermission {
                print("❌ 没有屏幕录制权限")
                await MainActor.run {
                    self.handlePermissionDenied()
                }
                return
            }
            
            print("✅ 屏幕录制权限检查通过")
            
            // ✅ 步骤1: 检查OCR服务可用性
            await MainActor.run {
                self.processingStateText = "正在检查服务"
                self.progress = 0.1
                self.progressMessage = "正在检查OCR服务..."
            }
            
            // 检查OCR服务可用性
            self.checkOCRServiceAvailability { [weak self] isAvailable in
                guard let self = self else { return }
                
                if !isAvailable && !self.isTestMode {
                    self.handleServiceUnavailableError()
                    return
                }
                
                // ✅ 步骤2: 执行真实的OCR识别流程
                Task {
                    await self.performRealRecognition()
                }
            }
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
    private func performRealRecognition() async {
        print("📸 开始真实的OCR识别流程")
        
        // ✅ 步骤1: 截图
        await MainActor.run {
            processingStateText = "正在截取屏幕"
            progress = 0.2
            progressMessage = "正在截取屏幕..."
        }
        
        print("📸 步骤1: 开始截图")
        guard let screenshot = await ScreenCaptureService.shared.captureScreen() else {
            print("❌ 截图失败")
            await MainActor.run {
                handleError("截图失败：请确保已授予屏幕录制权限。\n\n请在iPhone设置 → 隐私与安全 → 屏幕录制中开启ExpenseTracker的权限。")
            }
            return
        }
        
        print("✅ 截图成功，图像尺寸: \(screenshot.size)")
        
        // ✅ 步骤2: OCR识别
        await MainActor.run {
            processingStateText = "正在识别"
            progress = 0.4
            progressMessage = "正在进行OCR文字识别..."
        }
        
        print("🔍 步骤2: 开始OCR识别")
        // ✅ 使用本地OCR识别（不调用后端API，避免重复调用）
        let ocrResult = await OCRService.shared.recognizeTextLocally(from: screenshot)
        
        switch ocrResult {
        case .success(let ocrData):
            print("✅ 本地OCR识别成功")
            print("📝 识别文本: \(ocrData.text.prefix(100))...")
            
            // ✅ 步骤3: 直接使用后端API解析并自动创建（使用parse-auto端点）
            await MainActor.run {
                processingStateText = "正在解析"
                progress = 0.7
                progressMessage = "正在解析支出信息..."
            }
            
            print("📊 步骤3: 开始解析识别结果（使用parse-auto端点）")
            
            // ✅ 直接使用parse-auto端点，避免重复调用
            OCRAPIService.shared.autoProcessOCRText(ocrData.text)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("❌ 后端解析失败: \(error)")
                            
                            // ✅ 增强错误处理：根据错误类型显示不同的提示
                            switch error {
                            case .ocrServiceUnavailable:
                                self?.handleServiceUnavailableError()
                            case .invalidOCRRecord:
                                // ✅ 新增：OCR记录创建失败的错误处理
                                self?.handleError("系统错误：无法创建OCR记录，请重试。\n\n如果问题持续存在，请联系技术支持。")
                            case .serverError(let message):
                                // ✅ 如果包含"文本解析失败"，应该已经在OCRAPIService中处理为空的OCRProcessResult
                                // 这里只处理其他服务器错误
                                self?.handleAutoExpenseFailure(message)
                            case .httpError(400, let message):
                                // ✅ 400错误如果包含"文本解析失败"，应该已经在OCRAPIService中处理
                                // 这里只处理其他400错误
                                self?.handleAutoExpenseFailure("请求错误: \(message)")
                            default:
                                self?.handleAutoExpenseFailure(error.localizedDescription)
                            }
                        }
                    },
                    receiveValue: { [weak self] result in
                        print("✅ 后端解析成功")
                        
                        // ✅ 步骤4: 处理解析结果
                        // result是OCRProcessResult类型，包含record和expense
                        Task { @MainActor in
                            self?.processRecognitionResult(result, rawText: ocrData.text, ocrRecord: result.record)
                        }
                    }
                )
                .store(in: &cancellables)
            
        case .failure(let error):
            print("❌ 本地OCR识别失败: \(error)")
            
            // ✅ 本地OCR失败的错误处理
            let errorMessage: String
            if let autoError = error as? AutoRecognitionError {
                switch autoError {
                case .serviceUnavailable:
                    errorMessage = "OCR服务暂时不可用，请稍后再试"
                case .networkError(let message):
                    errorMessage = "网络错误: \(message)"
                case .permissionDenied:
                    errorMessage = "需要屏幕录制权限才能识别账单\n\n请在iPhone设置 → 隐私与安全 → 屏幕录制中开启ExpenseTracker的权限。"
                case .ocrFailure(let message), .ocrFailed(let message):
                    errorMessage = "OCR识别失败: \(message)"
                default:
                    errorMessage = "OCR识别失败: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "OCR识别失败: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                handleError(errorMessage)
            }
        }
    }
    
    /// 处理识别结果
    private func processRecognitionResult(_ result: OCRProcessResult, rawText: String, ocrRecord: OCRRecord) {
        print("📋 步骤4: 处理识别结果")
        
        // ✅ OCRProcessResult已经包含record，直接使用
        let record = result.record
        let parsedData = record.parsedData
        
        // ✅ 如果已经自动创建了支出（autoConfirmed = true），则不需要再创建
        if result.autoConfirmed, let expenseResponse = result.expense {
            print("✅ 支出记录已自动创建: \(expenseResponse.id)")
            
            // ✅ 将ExpenseResponse转换为Expense
            let expense = convertExpenseResponseToExpense(expenseResponse)
            
            handleExpenseCreationSuccess(expense)
            return
        }
        
        // 提取解析的数据（注意：OCRParsedData内部的字段是Optional的）
        let amount = parsedData.amount?.value ?? 0.0
        let merchant = parsedData.merchant?.name ?? ""
        let date: Date = {
            if let dateString = parsedData.date?.value {
                // 尝试解析日期字符串
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: dateString) ?? Date()
            }
            return Date()
        }()
        let paymentMethod = parsedData.paymentMethod?.type ?? ""
        let category = parsedData.category?.name ?? ""
        
        // ✅ 检查是否是空记录（解析失败但recordId存在的情况）
        let isEmptyRecord = amount == 0.0 && merchant.isEmpty && paymentMethod.isEmpty && category.isEmpty
        
        print("💰 解析结果:")
        print("  金额: \(amount)")
        print("  商户: \(merchant.isEmpty ? "(空)" : merchant)")
        print("  日期: \(date)")
        print("  支付方式: \(paymentMethod.isEmpty ? "(空)" : paymentMethod)")
        print("  类别: \(category.isEmpty ? "(空)" : category)")
        print("  置信度: \(record.confidenceScore)")
        print("  是否为空记录: \(isEmptyRecord)")
        
        // 创建自动记账结果
        let autoExpenseData = AutoExpenseData(
            amount: amount,
            merchant: merchant.isEmpty ? nil : merchant,  // 空字符串转为nil
            date: ISO8601DateFormatter().string(from: date),
            category: category.isEmpty ? nil : category,  // 空字符串转为nil
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,  // 空字符串转为nil
            notes: isEmptyRecord ? "OCR无法识别，请手动输入账单信息" : nil,
            confidence: Double(record.confidenceScore),
            rawText: rawText
        )
        
        // ✅ 如果是空记录（解析失败），总是需要用户确认
        let confidence = Double(record.confidenceScore)
        let requiresConfirmation = isEmptyRecord || requiresUserConfirmation(confidence: confidence)
        
        if requiresConfirmation {
            if isEmptyRecord {
                print("⚠️ OCR解析失败，需要用户手动输入账单信息")
                processingStateText = "需要手动输入"
                progressMessage = "OCR无法识别账单信息，请手动输入..."
            } else {
                print("⚠️ 置信度较低(\(confidence))，需要用户确认")
                processingStateText = "等待确认"
                progressMessage = "识别完成，请确认信息..."
            }
            progress = 0.9
        } else {
            print("✅ 置信度较高(\(confidence))，自动创建支出记录")
            processingStateText = "正在创建"
            progress = 0.9
            progressMessage = "正在创建支出记录..."
        }
        
        // 保存结果
        currentAutoExpenseResult = autoExpenseData
        currentRecordId = record.id  // ✅ 保存recordId，用于确认时创建支出
        hasRecognitionResult = true
        
        // 如果需要确认，显示确认界面
        if requiresConfirmation {
            print("⚠️ 需要用户确认，显示确认界面")
            // ✅ 已经在@MainActor上下文中，直接设置即可
            showConfirmationView = true
            print("✅ showConfirmationView已设置为true: \(showConfirmationView)")
            print("✅ currentAutoExpenseResult: \(currentAutoExpenseResult != nil ? "存在" : "nil")")
            print("✅ currentRecordId: \(currentRecordId ?? "nil")")
            return
        }
        
        // ✅ 高置信度：自动创建支出记录
        print("✅ 开始自动创建支出记录")
        // 使用后端返回的recordId（record已经在上面被提取）
        autoCreateExpense(from: autoExpenseData, recordId: record.id)
    }
    
    /// 使用OCR识别的数据（当后端未返回record时）
    private func processWithParsedData(parsedData: OCRParsedData, rawText: String, recordId: String, confidence: Double) {
        print("📋 使用OCR识别的数据")
        
        // 提取解析的数据
        let amount = parsedData.amount?.value ?? 0.0
        let merchant = parsedData.merchant?.name ?? "未知商户"
        let date: Date = {
            if let dateString = parsedData.date?.value {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: dateString) ?? Date()
            }
            return Date()
        }()
        let paymentMethod = parsedData.paymentMethod?.type ?? "未知支付方式"
        let category = parsedData.category?.name ?? "其他"
        
        // 创建自动记账结果
        let autoExpenseData = AutoExpenseData(
            amount: amount,
            merchant: merchant,
            date: ISO8601DateFormatter().string(from: date),
            category: category,
            paymentMethod: paymentMethod,
            notes: nil,
            confidence: confidence,
            rawText: rawText
        )
        
        // 根据置信度决定是否需要用户确认
        let requiresConfirmation = requiresUserConfirmation(confidence: confidence)
        
        // 保存结果
        currentAutoExpenseResult = autoExpenseData
        hasRecognitionResult = true
        
        if requiresConfirmation {
            print("⚠️ 需要用户确认，等待用户操作")
            processingStateText = "等待确认"
            progress = 0.9
            progressMessage = "识别完成，请确认信息..."
            return
        }
        
        // 高置信度：自动创建支出记录
        print("✅ 开始自动创建支出记录")
        autoCreateExpense(from: autoExpenseData, recordId: recordId)
    }
    
    /// 根据置信度判断是否需要用户确认
    private func requiresUserConfirmation(confidence: Double) -> Bool {
        // ✅ 从UserDefaults读取保存的设置
        var threshold: Double = 0.8 // 默认阈值
        
        if let savedData = UserDefaults.standard.data(forKey: "automationSettings"),
           let settings = try? JSONDecoder().decode(AutomationSettings.self, from: savedData) {
            threshold = settings.confidenceThreshold
            print("📖 从UserDefaults读取置信度阈值: \(threshold)")
        } else {
            print("⚠️ 未找到保存的设置，使用默认阈值: \(threshold)")
        }
        
        return confidence < threshold
    }
    
    /// 自动创建支出记录（高置信度时）
    private func autoCreateExpense(from data: AutoExpenseData, recordId: String) {
        print("💰 自动创建支出记录")
        
        // 更新状态
        processingStateText = "正在创建"
        progress = 0.9
        progressMessage = "正在创建支出记录..."
        
        // ✅ 映射中文类别到英文rawValue
        let category: ExpenseCategory? = {
            guard let categoryName = data.category else { return nil }
            return mapCategoryNameToEnum(categoryName)
        }()
        
        // ✅ 映射中文支付方式到英文rawValue
        let paymentMethod: PaymentMethod? = {
            guard let methodName = data.paymentMethod else { return nil }
            return mapPaymentMethodNameToEnum(methodName)
        }()
        
        // 构建ExpenseCorrections
        let corrections = ExpenseCorrections(
            amount: data.amount,
            category: category,
            description: data.notes,
            date: data.date.flatMap { ISO8601DateFormatter().date(from: $0) },
            location: nil,
            paymentMethod: paymentMethod,
            tags: nil
        )
        
        // 调用AutoExpenseService创建支出
        autoExpenseService.confirmAndCreateExpense(recordId: recordId, corrections: corrections)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                switch result {
                case .success(let expense):
                    print("✅ 支出记录创建成功: \(expense.id)")
                    self?.handleExpenseCreationSuccess(expense)
                case .failure(let error):
                    print("❌ 支出记录创建失败: \(error)")
                    self?.handleExpenseCreationFailure(error)
                }
            }
            .store(in: &cancellables)
    }
    
    /// 映射中文类别名称到ExpenseCategory枚举
    private func mapCategoryNameToEnum(_ name: String) -> ExpenseCategory? {
        let mapping: [String: ExpenseCategory] = [
            "餐饮": .food,
            "交通": .transport,
            "娱乐": .entertainment,
            "购物": .shopping,
            "账单": .bills,
            "医疗": .healthcare,
            "教育": .education,
            "旅行": .travel,
            "其他": .other
        ]
        
        // 先尝试直接匹配
        if let category = mapping[name] {
            return category
        }
        
        // 尝试使用rawValue匹配（如果后端返回的是英文）
        return ExpenseCategory(rawValue: name.lowercased())
    }
    
    /// 将ExpenseResponse转换为Expense
    private func convertExpenseResponseToExpense(_ response: ExpenseResponse) -> Expense {
        // ✅ 解析日期字符串为Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let date = formatter.date(from: response.date) ?? Date()
        let createdAt = formatter.date(from: response.createdAt) ?? Date()
        let updatedAt = response.updatedAt.flatMap { formatter.date(from: $0) } ?? Date()
        
        return Expense(
            id: response.id,
            userId: response.userId,
            amount: response.amount,
            category: response.category,
            description: response.description,
            date: date,
            location: response.location,
            paymentMethod: response.paymentMethod,
            tags: response.tags ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// 映射中文支付方式名称到PaymentMethod枚举
    /// 支持带银行名称的格式（如"工商银行信用卡"）
    private func mapPaymentMethodNameToEnum(_ name: String) -> PaymentMethod? {
        let mapping: [String: PaymentMethod] = [
            "现金": .cash,
            "银行卡": .card,
            "信用卡": .creditCard,
            "借记卡": .debitCard,
            "微信支付": .wechatPay,
            "微信": .wechatPay,
            "支付宝": .alipay,
            "在线支付": .online,
            "银行转账": .bankTransfer,
            "其他": .other
        ]
        
        // ✅ 先尝试直接匹配
        if let method = mapping[name] {
            return method
        }
        
        // ✅ 处理带银行名称的格式（如"工商银行信用卡"、"建设银行借记卡"）
        // 提取支付方式类型（移除银行名称）
        let paymentTypeKeywords = [
            "信用卡": "信用卡",
            "借记卡": "借记卡",
            "银行卡": "银行卡",
            "储蓄卡": "借记卡"
        ]
        
        for (keyword, type) in paymentTypeKeywords {
            if name.contains(keyword) {
                // 找到对应的支付方式类型
                if let method = mapping[type] {
                    return method
                }
            }
        }
        
        // ✅ 尝试使用rawValue匹配（如果后端返回的是英文）
        return PaymentMethod(rawValue: name.lowercased())
    }
    
    /// 处理权限被拒绝的情况
    private func handlePermissionDenied() {
        print("❌ 处理权限被拒绝")
        processingStateText = "权限不足"
        progress = 0.0
        progressMessage = ""
        errorMessage = "需要屏幕录制权限才能自动识别账单\n\n请在iPhone设置 → 隐私与安全 → 屏幕录制中开启ExpenseTracker的权限。"
        hasRecognitionResult = false
        currentAutoExpenseResult = nil
    }
    
    /// 处理错误
    private func handleError(_ message: String) {
        print("❌ 处理错误: \(message)")
        processingStateText = "识别失败"
        progress = 0.0
        progressMessage = ""
        errorMessage = message
        hasRecognitionResult = false
        currentAutoExpenseResult = nil
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
        
        // ✅ 使用保存的recordId，如果没有则使用生成ID（向后兼容）
        guard let recordId = currentRecordId else {
            errorMessage = "缺少记录ID，无法创建支出"
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
            recordId: recordId,  // ✅ 使用保存的recordId
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
        
        // ✅ 立即关闭确认界面
        showConfirmationView = false
        
        // 清理状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.processingStateText = "待机"
            self.progress = 0.0
            self.progressMessage = ""
            self.hasRecognitionResult = false
            self.currentAutoExpenseResult = nil
            self.currentRecordId = nil  // ✅ 清空recordId
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
            // ✅ 实际的识别流程（使用Task调用async函数）
            Task {
                await performRealRecognition()
            }
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