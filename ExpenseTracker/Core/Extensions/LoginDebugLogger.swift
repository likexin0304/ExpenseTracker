import Foundation
import Combine
import os.log

class LoginDebugLogger {
    static let shared = LoginDebugLogger()
    private let logger = Logger(subsystem: "ExpenseTracker", category: "LoginDebug")
    private var logMessages: [String] = []
    // 用于存储 Combine 订阅，方便在需要时统一管理
    var cancellables = Set<AnyCancellable>()
    
    private init() {
        clearLog()
        log("🚀 LoginDebugLogger 初始化完成")
    }
    
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = DateFormatter.debugFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)"
        
        logMessages.append(logMessage)
        
        // 同时输出到控制台
        print("🔍 \(logMessage)")
        logger.info("\(logMessage)")
        
        // 保持最近1000条日志
        if logMessages.count > 1000 {
            logMessages.removeFirst(100)
        }
    }
    
    func clearLog() {
        logMessages.removeAll()
        log("📝 日志已清空")
    }
    
    func getLogContent() -> String {
        return logMessages.joined(separator: "\n")
    }
    
    func saveLogToFile() -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let logFileURL = documentsPath?.appendingPathComponent("login_debug.log")
        
        do {
            try getLogContent().write(to: logFileURL!, atomically: true, encoding: .utf8)
            log("💾 日志已保存到: \(logFileURL!.path)")
            return logFileURL?.path
        } catch {
            log("❌ 保存日志失败: \(error)")
            return nil
        }
    }
}

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
} 