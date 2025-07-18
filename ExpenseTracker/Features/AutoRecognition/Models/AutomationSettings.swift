import Foundation

/// 自动化级别
enum AutomationLevel: String, CaseIterable {
    case manual = "manual"
    case smart = "smart"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .manual:
            return "手动确认"
        case .smart:
            return "智能自动"
        case .automatic:
            return "完全自动"
        }
    }
    
    var description: String {
        switch self {
        case .manual:
            return "每次识别结果都需要用户确认后才创建支出记录"
        case .smart:
            return "根据识别结果的置信度决定是否需要用户确认"
        case .automatic:
            return "自动创建所有识别结果的支出记录，无需用户确认"
        }
    }
    
    var icon: String {
        switch self {
        case .manual:
            return "hand.raised"
        case .smart:
            return "brain"
        case .automatic:
            return "bolt"
        }
    }
}

/// 自动化设置
struct AutomationSettings {
    var level: AutomationLevel = .manual
    var confidenceThreshold: Double = 0.8
    var enableNotifications: Bool = true
    var enableBackTap: Bool = false
    var triggerDelay: Double = 0.5
    var saveHistory: Bool = true
    var maxHistoryCount: Int = 50
    var debugMode: Bool = false
    
    var isValid: Bool {
        if level == .smart {
            return confidenceThreshold >= 0.5 && confidenceThreshold <= 0.95
        }
        return true
    }
    
    var name: String {
        switch level {
        case .manual:
            return "基础模式"
        case .smart:
            return "智能模式"
        case .automatic:
            return "高级模式"
        }
    }
    
    var summary: String {
        switch level {
        case .manual:
            return "手动确认所有识别结果"
        case .smart:
            return "智能自动处理，置信度阈值\(Int(confidenceThreshold * 100))%"
        case .automatic:
            return "完全自动处理所有识别结果"
        }
    }
    
    /// 根据置信度判断是否需要用户确认
    func requiresUserConfirmation(confidence: Double) -> Bool {
        switch level {
        case .manual:
            return true
        case .smart:
            return confidence < confidenceThreshold
        case .automatic:
            return false
        }
    }
}

/// 自动化配置选项
struct AutomationOption {
    let title: String
    let description: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
}

// MARK: - 预设配置

extension AutomationSettings {
    static var basic: AutomationSettings {
        var settings = AutomationSettings()
        settings.level = .manual
        settings.enableNotifications = true
        settings.enableBackTap = false
        settings.saveHistory = true
        settings.maxHistoryCount = 30
        settings.debugMode = false
        return settings
    }
    
    static var smart: AutomationSettings {
        var settings = AutomationSettings()
        settings.level = .smart
        settings.confidenceThreshold = 0.8
        settings.enableNotifications = true
        settings.enableBackTap = true
        settings.triggerDelay = 0.5
        settings.saveHistory = true
        settings.maxHistoryCount = 50
        settings.debugMode = false
        return settings
    }
    
    static var advanced: AutomationSettings {
        var settings = AutomationSettings()
        settings.level = .automatic
        settings.enableNotifications = true
        settings.enableBackTap = true
        settings.triggerDelay = 0.3
        settings.saveHistory = true
        settings.maxHistoryCount = 100
        settings.debugMode = false
        return settings
    }
} 