import Foundation
import SwiftUI
import Combine

/// 自动识别服务
class AutoRecognitionService: ObservableObject, AutoRecognitionServiceProtocol {
    /// 单例
    static let shared = AutoRecognitionService()
    
    // MARK: - Published Properties
    
    /// 当前状态
    @Published var state: AutoRecognitionState
    
    /// 日志服务
    private let logger = LoggingService.shared
    
    /// 状态订阅
    private var cancellables = Set<AnyCancellable>()
    
    /// 初始化
    private init() {
        // 创建初始状态
        self.state = AutoRecognitionState()
        
        // 设置状态订阅
        setupSubscriptions()
    }
    
    /// 设置状态订阅
    private func setupSubscriptions() {
        // 监听测试模式变化
        $state
            .map(\.isTestMode)
            .removeDuplicates()
            .sink { [weak self] isTestMode in
                self?.handleTestModeChange(isTestMode)
            }
            .store(in: &cancellables)
        
        // 监听处理状态变化
        $state
            .map(\.processingState)
            .removeDuplicates()
            .sink { [weak self] processingState in
                self?.handleProcessingStateChange(processingState)
            }
            .store(in: &cancellables)
    }
    
    /// 处理状态变更
    /// - Parameter action: 动作
    private func dispatch(_ action: AutoRecognitionAction) {
        AutoRecognitionReducer.reduce(state: &state, action: action)
        
        // 记录状态变更
        logger.log("状态变更: \(action)", category: .recognition)
    }
    
    /// 处理测试模式变化
    /// - Parameter isTestMode: 是否处于测试模式
    private func handleTestModeChange(_ isTestMode: Bool) {
        logger.log("测试模式已\(isTestMode ? "启用" : "禁用")", category: .recognition)
    }
    
    /// 处理处理状态变化
    /// - Parameter processingState: 处理状态
    private func handleProcessingStateChange(_ processingState: ProcessingState) {
        logger.log("处理状态变更: \(processingState.displayText)", category: .recognition)
        
        // 根据不同状态执行相应操作
        switch processingState {
        case .waitingForConfirmation:
            // 在测试模式下自动确认
            if state.isTestMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    Task {
                        await self?.startRecognition()
                    }
                }
            }
            
        case .capturingScreen:
            if state.isTestMode {
                simulateCapturing()
            } else {
                performCapturing()
            }
            
        case .recognizing:
            if state.isTestMode {
                simulateRecognizing()
            } else {
                performRecognizing()
            }
            
        case .parsing:
            if state.isTestMode {
                simulateParsing()
            } else {
                performParsing()
            }
            
        case .success(let result):
            logger.log("识别成功: \(result.merchantName ?? "未知商户")", category: .recognition)
            
        case .failed(let error):
            logger.log("识别失败: \(error.localizedDescription)", category: .recognition)
            
        case .cancelled:
            logger.log("识别已取消", category: .recognition)
            
        case .idle:
            // 空闲状态，无需处理
            break
        }
    }
    
    // MARK: - AutoRecognitionServiceProtocol Implementation
    
    /// 开始识别
    func startRecognition() async {
        dispatch(.updateProcessingState(.capturingScreen))
    }
    
    /// 停止识别
    func stopRecognition() {
        dispatch(.cancelRecognition)
    }
    
    /// 设置启用状态
    func setEnabled(_ enabled: Bool) {
        dispatch(.setEnabled(enabled))
    }
    
    /// 设置测试模式
    func setTestMode(_ enabled: Bool) {
        dispatch(.setTestMode(enabled))
    }
    
    /// 清除结果
    func clearResults() {
        dispatch(.clearResults)
    }
    
    /// 重置状态
    func reset() {
        dispatch(.reset)
    }
    
    // MARK: - Additional Public Methods
    
    /// 切换功能开关
    func toggleEnabled() {
        dispatch(.toggleEnabled)
    }
    
    /// 切换测试模式
    func toggleTestMode() {
        dispatch(.toggleTestMode)
    }
    
    /// 手动触发识别
    func manualTrigger() {
        dispatch(.manualTrigger)
    }
    
    /// 取消识别
    func cancelRecognition() {
        dispatch(.cancelRecognition)
    }
    
    /// 重试识别
    func retryRecognition() {
        dispatch(.retryRecognition)
    }
    
    /// 确认结果
    func confirmResult() {
        dispatch(.confirmResult)
    }
    
    /// 显示教程
    func showTutorial() {
        dispatch(.showTutorial)
    }
    
    /// 完成教程
    func completeTutorial() {
        dispatch(.completeTutorial)
    }
    
    /// 清除日志
    func clearLogs() {
        dispatch(.clearLogs)
    }
    
    // MARK: - Private Simulation Methods
    
    /// 模拟截取屏幕
    private func simulateCapturing() {
        dispatch(.updateProgress(0.2, "正在截取屏幕..."))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dispatch(.updateProcessingState(.recognizing))
        }
    }
    
    /// 执行真实截取屏幕
    private func performCapturing() {
        dispatch(.updateProgress(0.2, "正在截取屏幕..."))
        
        // TODO: 实现真实的屏幕截取逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.dispatch(.updateProcessingState(.recognizing))
        }
    }
    
    /// 模拟识别
    private func simulateRecognizing() {
        dispatch(.updateProgress(0.5, "正在识别内容..."))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.dispatch(.updateProcessingState(.parsing))
        }
    }
    
    /// 执行真实识别
    private func performRecognizing() {
        dispatch(.updateProgress(0.5, "正在识别内容..."))
        
        // TODO: 实现真实的OCR识别逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.dispatch(.updateProcessingState(.parsing))
        }
    }
    
    /// 模拟解析
    private func simulateParsing() {
        dispatch(.updateProgress(0.8, "正在解析数据..."))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 创建测试数据
            let result = RecognitionResult.createTestData()
            self?.dispatch(.updateProcessingState(.success(result)))
        }
    }
    
    /// 执行真实解析
    private func performParsing() {
        dispatch(.updateProgress(0.8, "正在解析数据..."))
        
        // TODO: 实现真实的数据解析逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // 创建测试数据
            let result = RecognitionResult.createTestData()
            self?.dispatch(.updateProcessingState(.success(result)))
        }
    }
} 