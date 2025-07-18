import Foundation
import os.log
import SwiftUI

/// 日志类别
enum LogCategory {
    case general
    case network
    case database
    case ui
    case recognition
    case debug
    case error
    case backTap
    
    var prefix: String {
        switch self {
        case .general: return "📝"
        case .network: return "🌐"
        case .database: return "💾"
        case .ui: return "🖼️"
        case .recognition: return "👁️"
        case .debug: return "🐞"
        case .error: return "❌"
        case .backTap: return "👆"
        }
    }
}

/// 日志服务协议
protocol LoggingServiceProtocol {
    func log(_ message: String, category: LogCategory)
    func setTestMode(_ enabled: Bool)
    func logBackTap(tapCount: Int, requiredCount: Int, intensity: Double, triggered: Bool)
}

/// 日志服务
class LoggingService: LoggingServiceProtocol {
    /// 单例
    static let shared = LoggingService()
    
    /// 是否启用日志
    var isEnabled: Bool = true
    
    /// 日志级别
    var logLevel: LogLevel = .info
    
    /// 是否处于测试模式
    private var isTestMode: Bool = false
    
    /// 测试模式下的日志计数
    private var logCount: Int = 0
    
    /// 测试模式下最大日志数量
    private let maxTestModeLogs: Int = 100
    
    /// 系统日志器
    private let logger: Logger
    
    /// 文件日志器
    private let fileLogger: FileLogger
    
    /// 日志级别枚举
    enum LogLevel: Int {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        case none = 5
        
        var prefix: String {
            switch self {
            case .verbose: return "🔍 VERBOSE"
            case .debug: return "🔧 DEBUG"
            case .info: return "ℹ️ INFO"
            case .warning: return "⚠️ WARNING"
            case .error: return "❌ ERROR"
            case .none: return ""
            }
        }
    }
    
    /// 私有初始化
    private init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.expensetracker", category: "ExpenseTracker")
        self.fileLogger = FileLogger()
    }
    
    /// 设置测试模式
    /// - Parameter enabled: 是否启用测试模式
    func setTestMode(_ enabled: Bool) {
        isTestMode = enabled
        if enabled {
            logCount = 0
        }
    }
    
    /// 记录日志 - 协议实现
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    func log(_ message: String, category: LogCategory) {
        log(message, level: .info, category: category)
    }
    
    /// 记录日志 - 完整版本
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    ///   - category: 日志类别
    ///   - file: 文件名
    ///   - function: 函数名
    ///   - line: 行号
    func log(_ message: String,
             level: LogLevel = .info,
             category: LogCategory = .general,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        // 检查日志级别
        guard isEnabled && level.rawValue >= logLevel.rawValue else {
            return
        }
        
        // 在测试模式下限制日志数量，避免过多日志导致性能问题
        if isTestMode {
            // 在测试模式下，只记录错误和警告，或者重要的状态变更
            if level == .debug && category != .error && category != .backTap {
                return
            }
            
            // 限制日志数量
            logCount += 1
            if logCount > maxTestModeLogs {
                // 超过最大数量，只记录错误和警告
                if level != .error && level != .warning {
                    return
                }
            }
        }
        
        // 获取文件名
        let fileName = (file as NSString).lastPathComponent
        
        // 格式化日志
        let logMessage = "\(level.prefix) \(category.prefix) [\(fileName):\(line)] \(function): \(message)"
        
        // 使用系统日志
        switch level {
        case .debug:
            logger.debug("\(logMessage, privacy: .public)")
        case .info:
            logger.info("\(logMessage, privacy: .public)")
        case .warning:
            logger.warning("\(logMessage, privacy: .public)")
        case .error:
            logger.error("\(logMessage, privacy: .public)")
        case .verbose:
            logger.debug("\(logMessage, privacy: .public)")
        case .none:
            break
        }
        
        // 使用文件日志
        let fullLogMessage = "[\(Date())] \(logMessage) (\(fileName):\(line) \(function))"
        fileLogger.log(fullLogMessage)
        
        // 在开发环境下也打印到控制台
        #if DEBUG
        print(fullLogMessage)
        #endif
    }
    
    /// 记录错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - category: 日志类别
    ///   - file: 文件名
    ///   - function: 函数名
    ///   - line: 行号
    func logError(_ error: Error,
                  category: LogCategory = .error,
                  file: String = #file,
                  function: String = #function,
                  line: Int = #line) {
        log("Error: \(error.localizedDescription)", level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// 记录背面敲击事件
    /// - Parameters:
    ///   - tapCount: 当前敲击次数
    ///   - requiredCount: 所需敲击次数
    ///   - intensity: 敲击强度
    ///   - triggered: 是否触发了回调
    func logBackTap(tapCount: Int, requiredCount: Int, intensity: Double, triggered: Bool = false) {
        // 在测试模式下减少背面敲击日志
        if isTestMode && !triggered {
            return
        }
        
        let status = triggered ? "触发回调" : "记录敲击"
        log(
            "敲击检测 \(tapCount)/\(requiredCount) (强度: \(String(format: "%.2f", intensity))) - \(status)",
            level: triggered ? .info : .debug,
            category: .backTap
        )
    }
    
    /// 获取日志文件内容
    func getLogFileContent() -> String {
        return fileLogger.readLogFile() ?? "无日志记录"
    }
    
    /// 清除日志文件
    func clearLogs() {
        fileLogger.clearLogFile()
        logCount = 0
    }
}

/// 文件日志器
class FileLogger {
    /// 日志文件URL
    private let logFileURL: URL
    
    /// 文件管理器
    private let fileManager = FileManager.default
    
    /// 初始化
    init() {
        // 获取文档目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建日志文件URL
        logFileURL = documentsDirectory.appendingPathComponent("app_logs.txt")
        
        // 创建日志文件（如果不存在）
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
    }
    
    /// 记录日志
    /// - Parameter message: 日志消息
    func log(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        
        if fileManager.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
    
    /// 读取日志文件
    /// - Returns: 日志内容
    func readLogFile() -> String? {
        try? String(contentsOf: logFileURL, encoding: .utf8)
    }
    
    /// 清除日志文件
    func clearLogFile() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
} 