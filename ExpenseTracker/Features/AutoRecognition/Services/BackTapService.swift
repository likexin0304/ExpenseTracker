import UIKit
import Combine
import CoreMotion

/**
 * Back Tap检测服务 - Phase 3 真机版本
 * 使用CoreMotion检测设备背面敲击手势
 */
@available(iOS 14.0, *)
class BackTapService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否启用Back Tap检测
    @Published var isEnabled: Bool = false
    
    /// 检测状态
    @Published var detectionStatus: String = "未启用"
    
    /// 敲击强度
    @Published var tapIntensity: Double = 0.0
    
    // MARK: - Private Properties
    
    /// 运动管理器
    private let motionManager = CMMotionManager()
    
    /// 敲击回调
    private var onBackTapDetected: (() -> Void)?
    
    /// 敲击计数器
    private var tapCount: Int = 0
    
    /// 敲击时间窗口
    private let tapTimeWindow: TimeInterval = 1.5
    
    /// 敲击计时器
    private var tapTimer: Timer?
    
    /// 敲击阈值
    private let tapThreshold: Double = 2.5
    
    /// 最小敲击间隔
    private let minTapInterval: TimeInterval = 0.1
    
    /// 上次敲击时间
    private var lastTapTime: TimeInterval = 0
    
    /// 运动数据队列
    private let motionQueue = OperationQueue()
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    /// 配置
    private var configuration = BackTapConfiguration()
    
    /// 日志服务
    private let loggingService = LoggingService.shared
    
    // MARK: - Singleton
    
    static let shared = BackTapService()
    
    private init() {
        setupMotionDetection()
        setupBackTapDetection()
        
        // 记录初始化日志
        loggingService.log("BackTapService初始化完成", category: .backTap)
    }
    
    // MARK: - Public Methods
    
    /**
     * 启用Back Tap检测
     * - Parameter callback: 检测到敲击时的回调
     */
    func enableBackTapDetection(callback: @escaping () -> Void) {
        loggingService.log("启用Back Tap检测（真机版本）", category: .backTap)
        
        guard isSystemSupported() else {
            loggingService.log("系统不支持Back Tap功能", level: .warning, category: .backTap)
            detectionStatus = "系统不支持"
            return
        }
        
        guard isMotionAvailable() else {
            loggingService.log("设备不支持运动检测", level: .warning, category: .backTap)
            detectionStatus = "设备不支持"
            return
        }
        
        onBackTapDetected = callback
        isEnabled = true
        detectionStatus = "已启用"
        
        startMotionDetection()
        
        loggingService.log("Back Tap检测已启用（使用CoreMotion）", category: .backTap)
    }
    
    /**
     * 禁用Back Tap检测
     */
    func disableBackTapDetection() {
        loggingService.log("禁用Back Tap检测", category: .backTap)
        
        isEnabled = false
        detectionStatus = "已禁用"
        onBackTapDetected = nil
        
        stopMotionDetection()
        
        loggingService.log("Back Tap检测已禁用", category: .backTap)
    }
    
    /**
     * 检查系统是否支持Back Tap
     */
    func isSystemSupported() -> Bool {
        // 检查设备是否支持Back Tap（主要是iPhone）
        let isSupported = UIDevice.current.userInterfaceIdiom == .phone && 
               ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0))
        
        loggingService.log("系统支持Back Tap: \(isSupported)", category: .backTap)
        return isSupported
    }
    
    /**
     * 检查运动传感器是否可用
     */
    func isMotionAvailable() -> Bool {
        let isAvailable = motionManager.isAccelerometerAvailable && motionManager.isGyroAvailable
        loggingService.log("运动传感器可用: \(isAvailable)", category: .backTap)
        return isAvailable
    }
    
    /**
     * 更新配置
     */
    func updateConfiguration(_ config: BackTapConfiguration) {
        configuration = config
        
        loggingService.log("更新Back Tap配置: 敲击次数=\(config.requiredTapCount), 时间窗口=\(config.tapTimeWindow)秒", category: .backTap)
        
        if isEnabled {
            // 重新启动检测以应用新配置
            stopMotionDetection()
            startMotionDetection()
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * 设置运动检测
     */
    private func setupMotionDetection() {
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.name = "BackTapMotionQueue"
        
        // 设置更新频率
        motionManager.accelerometerUpdateInterval = 0.01 // 100Hz
        motionManager.gyroUpdateInterval = 0.01
        
        loggingService.log("运动检测设置完成: 加速度计更新频率=100Hz", category: .backTap)
    }
    
    /**
     * 设置Back Tap检测
     */
    private func setupBackTapDetection() {
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                if self?.isEnabled == true {
                    self?.startMotionDetection()
                    self?.loggingService.log("应用进入前台，重新启动运动检测", category: .backTap)
                }
            }
            .store(in: &cancellables)
        
        // 注释掉后台停止检测，因为真正的背面轻点是系统级功能
        // NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        //     .sink { [weak self] _ in
        //         self?.stopMotionDetection()
        //         self?.loggingService.log("应用进入后台，停止运动检测", category: .backTap)
        //     }
        //     .store(in: &cancellables)
        
        // 注意：这个BackTapService主要用于测试和模拟
        // 真正的背面轻点功能由iOS系统的"辅助功能"→"触控"→"背面轻点"提供
        // 系统级的背面轻点不受应用前后台状态影响
        loggingService.log("⚠️ 注意：这是模拟的背面轻点检测，真正的功能需要在iPhone设置中配置", category: .backTap)
    }
    
    /**
     * 开始运动检测
     */
    private func startMotionDetection() {
        guard motionManager.isAccelerometerAvailable else {
            loggingService.log("加速度计不可用", level: .error, category: .backTap)
            return
        }
        
        // 开始加速度计更新
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] (data, error) in
            guard let self = self, let accelerometerData = data else { return }
            
            self.processAccelerometerData(accelerometerData)
        }
        
        loggingService.log("运动检测已开始", category: .backTap)
    }
    
    /**
     * 停止运动检测
     */
    private func stopMotionDetection() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        loggingService.log("运动检测已停止", category: .backTap)
    }
    
    /**
     * 处理加速度计数据
     */
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        
        // 计算总加速度（排除重力）
        let totalAcceleration = sqrt(
            pow(acceleration.x, 2) + 
            pow(acceleration.y, 2) + 
            pow(acceleration.z, 2)
        )
        
        // 更新敲击强度（在主线程）
        DispatchQueue.main.async {
            self.tapIntensity = totalAcceleration
        }
        
        // 检测敲击
        if totalAcceleration > tapThreshold {
            let currentTime = CACurrentMediaTime()
            
            // 检查最小敲击间隔
            if currentTime - lastTapTime > minTapInterval {
                lastTapTime = currentTime
                
                DispatchQueue.main.async {
                    self.handleBackTapDetected(intensity: totalAcceleration)
                }
            }
        }
    }
    
    /**
     * 处理Back Tap检测
     */
    private func handleBackTapDetected(intensity: Double) {
        tapCount += 1
        
        // 记录敲击日志
        loggingService.logBackTap(
            tapCount: tapCount,
            requiredCount: configuration.requiredTapCount,
            intensity: intensity
        )
        
        // 重置计时器
        tapTimer?.invalidate()
        tapTimer = Timer.scheduledTimer(withTimeInterval: configuration.tapTimeWindow, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // 记录敲击超时日志
            if self.tapCount > 0 {
                self.loggingService.log(
                    "敲击序列超时重置: 计数=\(self.tapCount)/\(self.configuration.requiredTapCount)",
                    category: .backTap
                )
            }
            
            self.resetTapCount()
        }
        
        // 检查是否达到要求的敲击次数
        if tapCount >= configuration.requiredTapCount {
            // 记录成功触发日志
            loggingService.logBackTap(
                tapCount: tapCount,
                requiredCount: configuration.requiredTapCount,
                intensity: intensity,
                triggered: true
            )
            
            resetTapCount()
            
            // 提供触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 触发回调
            onBackTapDetected?()
        }
    }
    
    /**
     * 重置敲击计数
     */
    private func resetTapCount() {
        tapCount = 0
        tapTimer?.invalidate()
        tapTimer = nil
    }
}

/**
 * Back Tap检测的替代实现 - Phase 3 扩展
 */
@available(iOS 14.0, *)
extension BackTapService {
    
    /**
     * 启用音量键组合检测（开发用）
     */
    func enableVolumeKeyDetection() {
        loggingService.log("启用音量键组合检测（开发模式）", category: .backTap)
        // 可以在这里实现音量键监听作为替代方案
    }
    
    /**
     * 手动触发Back Tap（测试用）
     */
    func simulateBackTap() {
        loggingService.log("模拟Back Tap触发", category: .backTap)
        
        // 提供触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.async {
            self.onBackTapDetected?()
        }
        
        loggingService.log("模拟Back Tap已触发回调", category: .backTap)
    }
    
    /**
     * 获取当前运动状态
     */
    func getMotionStatus() -> String {
        if !motionManager.isAccelerometerAvailable {
            return "加速度计不可用"
        }
        
        if !motionManager.isAccelerometerActive {
            return "加速度计未激活"
        }
        
        return "运动检测正常"
    }
    
    /**
     * 校准敲击阈值
     */
    func calibrateTapThreshold() {
        // 可以实现动态阈值校准
        loggingService.log("开始校准敲击阈值", category: .backTap)
    }
    
    /**
     * 获取敲击日志
     */
    func getBackTapLogs() -> String {
        return LoggingService.shared.getLogFileContent()
    }
}

/**
 * Back Tap配置 - Phase 3 增强版本
 */
struct BackTapConfiguration {
    /// 是否启用
    var isEnabled: Bool = false
    
    /// 敲击次数要求
    var requiredTapCount: Int = 3
    
    /// 敲击时间窗口（秒）
    var tapTimeWindow: TimeInterval = 1.5
    
    /// 敲击阈值
    var tapThreshold: Double = 2.5
    
    /// 最小敲击间隔
    var minTapInterval: TimeInterval = 0.1
    
    /// 是否使用替代检测方式
    var useAlternativeDetection: Bool = false
    
    /// 是否启用触觉反馈
    var enableHapticFeedback: Bool = true
    
    /// 调试模式
    var debugMode: Bool = false
} 