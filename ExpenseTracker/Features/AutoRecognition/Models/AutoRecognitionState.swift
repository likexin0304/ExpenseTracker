import Foundation

/**
 * 自动识别功能的状态枚举
 */
enum AutoRecognitionState: Equatable {
    /// 空闲状态
    case idle
    
    /// 等待用户确认是否开始识别
    case waitingForConfirmation
    
    /// 正在截取屏幕
    case capturingScreen
    
    /// 正在进行OCR识别
    case recognizing
    
    /// 正在解析数据
    case parsing
    
    /// 识别成功，等待用户确认
    case success(RecognitionResult)
    
    /// 识别失败
    case failed(AutoRecognitionError)
    
    /// 用户取消
    case cancelled
    
    // MARK: - 计算属性
    
    /// 是否正在处理中
    var isProcessing: Bool {
        switch self {
        case .capturingScreen, .recognizing, .parsing:
            return true
        default:
            return false
        }
    }
    
    /// 是否可以开始新的识别
    var canStartNewRecognition: Bool {
        switch self {
        case .idle, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
    
    /// 状态描述
    var description: String {
        switch self {
        case .idle:
            return "准备就绪"
        case .waitingForConfirmation:
            return "等待确认"
        case .capturingScreen:
            return "正在截取屏幕..."
        case .recognizing:
            return "正在识别文字..."
        case .parsing:
            return "正在解析数据..."
        case .success:
            return "识别成功"
        case .failed(let error):
            return "识别失败: \(error.localizedDescription)"
        case .cancelled:
            return "已取消"
        }
    }
}

/**
 * 自动识别错误类型
 */
enum AutoRecognitionError: LocalizedError, Equatable {
    /// 功能未启用
    case featureDisabled
    
    /// 权限被拒绝
    case permissionDenied
    
    /// 屏幕截图失败
    case screenCaptureFailed
    
    /// OCR识别失败
    case ocrFailed(String)
    
    /// 没有识别到有效金额
    case noValidAmountFound
    
    /// 网络错误
    case networkError(String)
    
    /// 系统不支持（iOS版本过低）
    case systemNotSupported
    
    /// 未知错误
    case unknown(String)
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "智能识别功能未启用"
        case .permissionDenied:
            return "需要屏幕录制权限才能使用此功能"
        case .screenCaptureFailed:
            return "屏幕截图失败，请重试"
        case .ocrFailed(let message):
            return "文字识别失败: \(message)"
        case .noValidAmountFound:
            return "未识别到有效的金额信息"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .systemNotSupported:
            return "当前系统版本不支持此功能，需要iOS 14.0或更高版本"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .featureDisabled:
            return "请在设置中启用智能识别功能"
        case .permissionDenied:
            return "请在系统设置中允许屏幕录制权限"
        case .screenCaptureFailed:
            return "请重新尝试，确保应用有足够的权限"
        case .ocrFailed(_):
            return "请确保屏幕内容清晰可见，避免复杂背景"
        case .noValidAmountFound:
            return "请确保屏幕上显示有明确的金额信息"
        case .networkError:
            return "请检查网络连接后重试"
        case .systemNotSupported:
            return "请升级到iOS 14.0或更高版本"
        case .unknown:
            return "请重新尝试，如果问题持续存在请联系客服"
        }
    }
}

/**
 * 权限状态枚举
 */
enum PermissionStatus {
    /// 未确定
    case notDetermined
    
    /// 已授权
    case authorized
    
    /// 被拒绝
    case denied
    
    /// 受限制
    case restricted
    
    /// 不支持
    case notSupported
}

/**
 * 功能设置配置
 */
struct AutoRecognitionSettings {
    /// 功能总开关
    var isEnabled: Bool = false
    
    /// 是否需要确认机制（防误触）
    var requiresConfirmation: Bool = true
    
    /// 确认等待时间（秒）
    var confirmationTimeout: TimeInterval = 5.0
    
    /// 默认分类
    var defaultCategory: ExpenseCategory = .other
    
    /// OCR识别最低置信度阈值
    var minimumOCRConfidence: Double = 0.5
    
    /// 分类推荐最低置信度阈值
    var minimumCategoryConfidence: Double = 0.3
    
    /// 是否显示调试信息
    var showDebugInfo: Bool = false
    
    // MARK: - UserDefaults键
    
    private enum Keys {
        static let isEnabled = "AutoRecognition.isEnabled"
        static let requiresConfirmation = "AutoRecognition.requiresConfirmation"
        static let confirmationTimeout = "AutoRecognition.confirmationTimeout"
        static let defaultCategory = "AutoRecognition.defaultCategory"
        static let minimumOCRConfidence = "AutoRecognition.minimumOCRConfidence"
        static let minimumCategoryConfidence = "AutoRecognition.minimumCategoryConfidence"
        static let showDebugInfo = "AutoRecognition.showDebugInfo"
    }
    
    // MARK: - 持久化
    
    /// 从UserDefaults加载设置
    static func load() -> AutoRecognitionSettings {
        let defaults = UserDefaults.standard
        
        return AutoRecognitionSettings(
            isEnabled: defaults.bool(forKey: Keys.isEnabled),
            requiresConfirmation: defaults.object(forKey: Keys.requiresConfirmation) as? Bool ?? true,
            confirmationTimeout: defaults.object(forKey: Keys.confirmationTimeout) as? TimeInterval ?? 5.0,
            defaultCategory: ExpenseCategory(rawValue: defaults.string(forKey: Keys.defaultCategory) ?? "") ?? .other,
            minimumOCRConfidence: defaults.object(forKey: Keys.minimumOCRConfidence) as? Double ?? 0.5,
            minimumCategoryConfidence: defaults.object(forKey: Keys.minimumCategoryConfidence) as? Double ?? 0.3,
            showDebugInfo: defaults.bool(forKey: Keys.showDebugInfo)
        )
    }
    
    /// 保存设置到UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(requiresConfirmation, forKey: Keys.requiresConfirmation)
        defaults.set(confirmationTimeout, forKey: Keys.confirmationTimeout)
        defaults.set(defaultCategory.rawValue, forKey: Keys.defaultCategory)
        defaults.set(minimumOCRConfidence, forKey: Keys.minimumOCRConfidence)
        defaults.set(minimumCategoryConfidence, forKey: Keys.minimumCategoryConfidence)
        defaults.set(showDebugInfo, forKey: Keys.showDebugInfo)
    }
} 