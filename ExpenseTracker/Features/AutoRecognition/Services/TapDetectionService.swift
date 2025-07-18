import Foundation
import UIKit
import CoreMotion
import Combine

/// 背敲检测服务
class TapDetectionService: ObservableObject {
    static let shared = TapDetectionService()
    
    @Published var isEnabled = false
    @Published var isListening = false
    @Published var tapCount = 0
    @Published var lastTapTime: Date?
    
    // 发布三次背敲检测状态
    @Published var isTripleBackTapDetected = false
    
    private var motionManager: CMMotionManager?
    private var tapDetectionTimer: Timer?
    private let tapThreshold: Double = 2.5  // 敲击阈值
    private let tapTimeWindow: TimeInterval = 0.5  // 敲击时间窗口
    private let requiredTapCount = 3  // 需要的敲击次数
    
    private var cancellables = Set<AnyCancellable>()
    private var isDetectionActive = false
    
    // 回调
    var onTripleTap: (() -> Void)?
    
    private init() {
        setupMotionManager()
        checkBackTapAvailability()
        print("🔍 TapDetectionService 初始化")
    }
    
    deinit {
        stopListening()
    }
    
    /// 设置运动管理器
    private func setupMotionManager() {
        motionManager = CMMotionManager()
        motionManager?.accelerometerUpdateInterval = 0.1
    }
    
    /// 检查背敲功能是否可用
    private func checkBackTapAvailability() {
        // iOS 14+ 才支持背敲功能
        if #available(iOS 14.0, *) {
            isEnabled = true
        } else {
            isEnabled = false
        }
    }
    
    /// 开始监听背敲
    func startListening() {
        guard isEnabled else {
            print("❌ 背敲检测不可用")
            return
        }
        
        guard let motionManager = motionManager,
              motionManager.isAccelerometerAvailable else {
            print("❌ 加速度计不可用")
            return
        }
        
        print("🎯 开始监听背敲")
        isListening = true
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            self.processAccelerometerData(data)
        }
    }
    
    /// 停止监听背敲
    func stopListening() {
        print("⏹️ 停止监听背敲")
        isListening = false
        motionManager?.stopAccelerometerUpdates()
        tapDetectionTimer?.invalidate()
        tapDetectionTimer = nil
        resetTapCount()
    }
    
    /// 处理加速度计数据
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = sqrt(
            data.acceleration.x * data.acceleration.x +
            data.acceleration.y * data.acceleration.y +
            data.acceleration.z * data.acceleration.z
        )
        
        // 检测敲击
        if acceleration > tapThreshold {
            handleTapDetected()
        }
    }
    
    /// 处理检测到的敲击
    private func handleTapDetected() {
        let now = Date()
        
        // 检查是否在时间窗口内
        if let lastTap = lastTapTime,
           now.timeIntervalSince(lastTap) < tapTimeWindow {
            tapCount += 1
        } else {
            tapCount = 1
        }
        
        lastTapTime = now
        
        print("👆 检测到敲击 \(tapCount)/\(requiredTapCount)")
        
        // 重置计时器
        tapDetectionTimer?.invalidate()
        tapDetectionTimer = Timer.scheduledTimer(withTimeInterval: tapTimeWindow, repeats: false) { [weak self] _ in
            self?.checkTapSequence()
        }
    }
    
    /// 检查敲击序列
    private func checkTapSequence() {
        if tapCount >= requiredTapCount {
            print("🎉 检测到三次敲击！")
            triggerTripleTap()
        }
        
        resetTapCount()
    }
    
    /// 触发三次敲击事件
    private func triggerTripleTap() {
        DispatchQueue.main.async {
            self.onTripleTap?()
        }
    }
    
    /// 重置敲击计数
    private func resetTapCount() {
        tapCount = 0
        lastTapTime = nil
    }
    
    /// 开始检测背敲
    func startDetection(completion: (() -> Void)? = nil) {
        guard !isDetectionActive else {
            print("⚠️ 背敲检测已经在运行")
            return
        }
        
        isDetectionActive = true
        print("🔍 开始背敲检测")
        
        // 设置回调
        self.onTripleTap = completion
        
        // 注意：实际的背敲检测需要通过iOS快捷指令或其他系统级方式实现
        // 这里提供一个模拟实现，实际项目中需要配置iOS系统的"背面轻点"功能
        
        // 模拟检测逻辑 - 实际应用中这部分会被iOS系统的背面轻点功能替代
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // 这里是模拟逻辑，实际中会通过快捷指令触发
                // 实际实现会通过iOS的"背面轻点"设置来触发快捷指令
            }
            .store(in: &cancellables)
    }
    
    /// 停止检测背敲
    func stopDetection() {
        guard isDetectionActive else {
            print("⚠️ 背敲检测未在运行")
            return
        }
        
        isDetectionActive = false
        cancellables.removeAll()
        print("🛑 停止背敲检测")
    }
    
    /// 手动触发背敲检测（用于测试或快捷指令回调）
    func triggerBackTap() {
        print("👆 检测到背敲")
        DispatchQueue.main.async {
            self.isTripleBackTapDetected = true
            
            // 重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTripleBackTapDetected = false
            }
        }
    }
    
    /// 检查是否支持背敲检测
    var isBackTapSupported: Bool {
        // iOS 14+ 支持背面轻点功能
        if #available(iOS 14.0, *) {
            return true
        }
        return false
    }
    
    /// 获取背敲设置指导
    var backTapSetupInstructions: String {
        return """
        要启用背敲检测，请按以下步骤设置：
        
        1. 打开"设置" > "辅助功能"
        2. 选择"触控" > "背面轻点"
        3. 选择"轻点三下"
        4. 选择"快捷指令"
        5. 选择 ExpenseTracker 创建的快捷指令
        
        设置完成后，轻敲手机背面三次即可触发自动记账功能。
        """
    }
}

// MARK: - 模拟背敲检测（用于测试）

extension TapDetectionService {
    /// 模拟三次敲击（用于测试）
    func simulateTripleTap() {
        print("🧪 模拟三次敲击")
        triggerTripleTap()
    }
    
    /// 启用/禁用背敲检测
    func toggleBackTap() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
}

// MARK: - 背敲检测状态

extension TapDetectionService {
    /// 获取背敲检测状态描述
    var statusDescription: String {
        if !isEnabled {
            return "背敲检测不可用（需要iOS 14+）"
        } else if isListening {
            return "正在监听背敲"
        } else {
            return "背敲检测已停止"
        }
    }
    
    /// 获取背敲检测图标
    var statusIcon: String {
        if !isEnabled {
            return "exclamationmark.triangle"
        } else if isListening {
            return "hand.tap.fill"
        } else {
            return "hand.tap"
        }
    }
    
    /// 获取背敲检测颜色
    var statusColor: UIColor {
        if !isEnabled {
            return .systemRed
        } else if isListening {
            return .systemGreen
        } else {
            return .systemGray
        }
    }
} 