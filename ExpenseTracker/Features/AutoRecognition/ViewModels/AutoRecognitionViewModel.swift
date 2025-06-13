import SwiftUI
import Combine
import Foundation

@MainActor
class AutoRecognitionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var state: AutoRecognitionState = .idle
    @Published var recognitionResult: RecognitionResult?
    @Published var isEnabled: Bool = false
    @Published var errorMessage: String?
    @Published var progress: Double = 0.0
    @Published var progressMessage: String = ""
    @Published var showTutorial: Bool = false
    @Published var isTestMode: Bool = false
    
    // MARK: - Services
    private let backTapService: BackTapService
    private let screenCaptureService: ScreenCaptureService
    private let ocrService: OCRService
    private let dataParsingService: DataParsingService
    private let networkRetryService: NetworkRetryService
    private let testService: AutoRecognitionTestService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let autoRecognitionEnabledKey = "AutoRecognitionEnabled"
    private let tutorialCompletedKey = "AutoRecognitionTutorialCompleted"
    
    // MARK: - Initialization
    init(
        backTapService: BackTapService = BackTapService.shared,
        screenCaptureService: ScreenCaptureService = ScreenCaptureService.shared,
        ocrService: OCRService = OCRService.shared,
        dataParsingService: DataParsingService = DataParsingService.shared,
        networkRetryService: NetworkRetryService = NetworkRetryService.shared,
        testService: AutoRecognitionTestService = AutoRecognitionTestService.shared
    ) {
        self.backTapService = backTapService
        self.screenCaptureService = screenCaptureService
        self.ocrService = ocrService
        self.dataParsingService = dataParsingService
        self.networkRetryService = networkRetryService
        self.testService = testService
        
        // 从UserDefaults加载设置
        self.isEnabled = userDefaults.bool(forKey: autoRecognitionEnabledKey)
        
        setupObservers()
        
        // 检查是否需要显示教程
        if !userDefaults.bool(forKey: tutorialCompletedKey) && isEnabled {
            showTutorial = true
        }
        
        // 如果功能已启用，开始监听背面敲击
        if isEnabled {
            startBackTapDetection()
        }
    }
    
    deinit {
        backTapService.disableBackTapDetection()
    }
    
    // MARK: - Public Methods
    
    /// 切换功能开关
    func toggleEnabled() {
        isEnabled.toggle()
        userDefaults.set(isEnabled, forKey: autoRecognitionEnabledKey)
        
        if isEnabled {
            // 检查是否需要显示教程
            if !userDefaults.bool(forKey: tutorialCompletedKey) {
                showTutorial = true
            } else {
                requestPermissionsAndStart()
            }
        } else {
            stopBackTapDetection()
            resetState()
        }
    }
    
    /// 完成教程
    func completeTutorial() {
        userDefaults.set(true, forKey: tutorialCompletedKey)
        showTutorial = false
        if isEnabled {
            requestPermissionsAndStart()
        }
    }
    
    /// 显示教程
    func showTutorialView() {
        showTutorial = true
    }
    
    /// 切换测试模式
    func toggleTestMode() {
        isTestMode.toggle()
    }
    
    /// 运行测试套件
    func runTestSuite() async {
        guard isTestMode else { return }
        await testService.runFullTestSuite()
    }
    
    /// 手动触发识别（用于测试）
    func manualTrigger() {
        guard isEnabled else { return }
        startRecognitionProcess()
    }
    
    /// 确认识别结果
    func confirmResult() {
        guard case .success(_) = state else { return }
        state = .idle
        recognitionResult = nil
        resetProgress()
    }
    
    /// 取消识别
    func cancelRecognition() {
        state = .cancelled
        recognitionResult = nil
        resetProgress()
        
        // 延迟重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.state = .idle
        }
    }
    
    /// 重试识别
    func retryRecognition() {
        startRecognitionProcess()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 监听背面敲击 - 使用升级后的BackTapService
        backTapService.enableBackTapDetection { [weak self] in
            Task { @MainActor in
                self?.startRecognitionProcess()
            }
        }
        
        // 监听网络重试服务状态
        networkRetryService.$isRetrying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRetrying in
                if isRetrying {
                    self?.progressMessage = "网络重试中..."
                }
            }
            .store(in: &cancellables)
    }
    
    private func requestPermissionsAndStart() {
        Task {
            let hasPermission = await screenCaptureService.requestPermission()
            if hasPermission {
                startBackTapDetection()
            } else {
                await MainActor.run {
                    self.isEnabled = false
                    self.userDefaults.set(false, forKey: self.autoRecognitionEnabledKey)
                    self.errorMessage = "需要屏幕录制权限才能使用自动识别功能"
                }
            }
        }
    }
    
    private func startBackTapDetection() {
        // BackTapService已经在setupObservers中启用
        // 升级后的服务支持真实的设备运动检测
        print("🎯 自动识别功能已启用，等待背面敲击...")
    }
    
    private func stopBackTapDetection() {
        backTapService.disableBackTapDetection()
        print("⏹️ 自动识别功能已禁用")
    }
    
    private func startRecognitionProcess() {
        guard state == .idle else { return }
        
        state = .waitingForConfirmation
        errorMessage = nil
        resetProgress()
        
        // 给用户2秒时间确认
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.state == .waitingForConfirmation {
                self.performRecognition()
            }
        }
    }
    
    private func performRecognition() {
        Task {
            do {
                // 步骤1: 截图
                await updateProgress(0.1, "正在截取屏幕...")
                state = .capturingScreen
                
                let screenshot = await screenCaptureService.captureScreen()
                
                guard let screenshot = screenshot else {
                    throw AutoRecognitionError.screenCaptureFailed
                }
                
                // 步骤2: OCR识别 - 使用网络重试服务
                await updateProgress(0.3, "正在识别文字...")
                state = .recognizing
                
                let ocrResult = try await networkRetryService.executeWithRetry(
                    operation: {
                        let result = await self.ocrService.recognizeText(from: screenshot)
                        switch result {
                        case .success(let data):
                            return data
                        case .failure(let error):
                            throw error
                        }
                    }
                )
                
                // 步骤3: 数据解析 - 使用网络重试服务
                await updateProgress(0.7, "正在解析数据...")
                state = .parsing
                
                let result = try await networkRetryService.executeWithRetry(
                    operation: {
                        let parseResult = await self.dataParsingService.parseOCRData(ocrResult)
                        switch parseResult {
                        case .success(let data):
                            return data
                        case .failure(let error):
                            throw error
                        }
                    }
                )
                
                // 步骤4: 完成
                await updateProgress(1.0, "识别完成")
                
                await MainActor.run {
                    self.recognitionResult = result
                    self.state = .success(result)
                }
                
                print("✅ 自动识别完成")
                print("💰 识别金额: \(result.amounts)")
                print("🏪 商家名称: \(result.merchantName ?? "未识别")")
                print("🏷️ 推荐分类: \(result.suggestedCategory.displayName)")
                
            } catch {
                await MainActor.run {
                    let autoRecognitionError: AutoRecognitionError
                    if let recognitionError = error as? AutoRecognitionError {
                        autoRecognitionError = recognitionError
                    } else {
                        autoRecognitionError = .unknown(error.localizedDescription)
                    }
                    self.state = .failed(autoRecognitionError)
                    self.errorMessage = "识别失败: \(error.localizedDescription)"
                }
                
                print("❌ 自动识别失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            self.progress = progress
            self.progressMessage = message
        }
    }
    
    private func resetProgress() {
        progress = 0.0
        progressMessage = ""
    }
    
    private func resetState() {
        state = .idle
        recognitionResult = nil
        errorMessage = nil
        resetProgress()
    }
}

// MARK: - Extensions

extension AutoRecognitionViewModel {
    /// 获取当前状态的显示文本
    var stateDisplayText: String {
        switch state {
        case .idle:
            return "等待触发"
        case .waitingForConfirmation:
            return "等待确认..."
        case .capturingScreen:
            return "正在截图"
        case .recognizing:
            return "正在识别"
        case .parsing:
            return "正在解析"
        case .success(_):
            return "识别成功"
        case .failed(_):
            return "识别失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    /// 是否正在处理中
    var isProcessing: Bool {
        switch state {
        case .capturingScreen, .recognizing, .parsing:
            return true
        default:
            return false
        }
    }
    
    /// 是否可以重试
    var canRetry: Bool {
        if case .failed(_) = state {
            return true
        }
        return false
    }
    
    /// 是否可以取消
    var canCancel: Bool {
        switch state {
        case .waitingForConfirmation, .capturingScreen, .recognizing, .parsing:
            return true
        default:
            return false
        }
    }
    
    /// 获取测试状态文本
    var testStatusText: String {
        switch testService.testStatus {
        case .idle:
            return "准备测试"
        case .running:
            return "测试进行中..."
        case .completed:
            return "测试完成"
        case .failed:
            return "测试失败"
        }
    }
    
    /// 获取测试进度
    var testProgress: Double {
        return testService.testProgress
    }
    
    /// 获取测试结果
    var testResults: [TestResult] {
        return testService.testResults
    }
} 