//
//  ShortcutService.swift
//  ExpenseTracker
//
//  Created by Assistant on 2024-12-31.
//

import Foundation
import Intents
import IntentsUI
import UIKit

/// 快捷指令服务
class ShortcutService: ObservableObject {
    static let shared = ShortcutService()
    
    // 快捷指令配置
    private let shortcutName = "ExpenseTracker自动记账"
    private let shortcutIdentifier = "com.expensetracker.auto-recognition"
    private let callbackURLScheme = "expensetracker://process-screenshot"
    
    @Published var isShortcutInstalled = false
    @Published var shortcutError: String?
    
    private init() {
        print("📱 ShortcutService初始化")
        checkShortcutInstallation()
    }
    
    // MARK: - 快捷指令管理
    
    /// 检查快捷指令是否已安装
    func checkShortcutInstallation() {
        print("🔍 检查快捷指令安装状态")
        
        // 通过URL Scheme检测快捷指令是否存在
        let shortcutURL = URL(string: "shortcuts://run-shortcut?name=\(shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        
        if let url = shortcutURL, UIApplication.shared.canOpenURL(url) {
            DispatchQueue.main.async {
                self.isShortcutInstalled = true
                print("✅ 快捷指令已安装")
            }
        } else {
            DispatchQueue.main.async {
                self.isShortcutInstalled = false
                print("❌ 快捷指令未安装")
            }
        }
    }
    
    /// 创建快捷指令
    func createShortcut() async throws {
        print("🛠️ 开始创建快捷指令")
        
        if #unavailable(iOS 14.0) {
            let error = "快捷指令功能需要iOS 14.0或更高版本"
            await MainActor.run {
                self.shortcutError = error
            }
            throw ShortcutError.executionFailed
        }
        
        do {
            // 创建截图意图
            let screenshotIntent = createScreenshotIntent()
            
            // 创建快捷指令
            guard let shortcut = INShortcut(intent: screenshotIntent) else {
                throw ShortcutError.executionFailed
            }
            
            // 设置快捷指令标题
            if let intent = shortcut.intent {
                intent.suggestedInvocationPhrase = "记账截图"
            }
            
            // 添加到用户的快捷指令库
            try await addShortcutToLibrary(shortcut)
            
            await MainActor.run {
                self.isShortcutInstalled = true
                self.shortcutError = nil
                print("✅ 快捷指令创建成功")
            }
            
        } catch {
            let errorMessage = "创建快捷指令失败: \(error.localizedDescription)"
            await MainActor.run {
                self.shortcutError = errorMessage
            }
            print("❌ \(errorMessage)")
            throw error
        }
    }
    
    /// 触发快捷指令
    func triggerShortcut() async throws {
        print("🚀 触发快捷指令")
        
        guard isShortcutInstalled else {
            let error = "快捷指令未安装，请先创建快捷指令"
            await MainActor.run {
                self.shortcutError = error
            }
            throw ShortcutError.notInstalled
        }
        
        // 构建快捷指令URL
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let shortcutURL = URL(string: "shortcuts://run-shortcut?name=\(encodedName)")
        
        guard let url = shortcutURL else {
            throw ShortcutError.invalidURL
        }
        
        // 在主线程打开快捷指令
        await MainActor.run {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ 快捷指令触发成功")
                    } else {
                        print("❌ 快捷指令触发失败")
                        self.shortcutError = "无法打开快捷指令"
                    }
                }
            } else {
                print("❌ 无法打开快捷指令URL")
                self.shortcutError = "快捷指令不可用"
            }
        }
    }
    
    /// 提供快捷指令模板下载链接
    func getShortcutTemplateURL() -> URL? {
        // 这里应该是实际的iCloud快捷指令分享链接
        // 需要手动创建一个标准的快捷指令并分享
        return URL(string: "https://www.icloud.com/shortcuts/your-shortcut-template-id")
    }
    
    /// 打开快捷指令应用
    func openShortcutsApp() {
        print("📱 打开快捷指令应用")
        
        let shortcutsURL = URL(string: "shortcuts://")!
        
        if UIApplication.shared.canOpenURL(shortcutsURL) {
            UIApplication.shared.open(shortcutsURL) { success in
                if success {
                    print("✅ 快捷指令应用已打开")
                } else {
                    print("❌ 无法打开快捷指令应用")
                }
            }
        } else {
            print("❌ 快捷指令应用不可用")
        }
    }
    
    // MARK: - 私有方法
    
    /// 创建截图意图
    @available(iOS 14.0, *)
    private func createScreenshotIntent() -> INIntent {
        // 创建一个自定义意图用于截图
        // 由于iOS限制，我们需要使用通用的意图类型
        let intent = INPlayMediaIntent()
        intent.suggestedInvocationPhrase = "记账截图"
        return intent
    }
    
    /// 将快捷指令添加到用户库
    @available(iOS 14.0, *)
    private func addShortcutToLibrary(_ shortcut: INShortcut) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // 使用INVoiceShortcutCenter添加快捷指令
            INVoiceShortcutCenter.shared.getAllVoiceShortcuts { shortcuts, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 检查是否已存在相同的快捷指令
                let existingShortcut = shortcuts?.first { voiceShortcut in
                    voiceShortcut.shortcut.intent?.identifier == shortcut.intent?.identifier
                }
                
                if existingShortcut != nil {
                    print("ℹ️ 快捷指令已存在，跳过创建")
                    continuation.resume()
                    return
                }
                
                // 创建新的语音快捷指令
                INVoiceShortcutCenter.shared.setShortcutSuggestions([shortcut])
                continuation.resume()
            }
        }
    }
    
    // MARK: - 数据传输处理
    
    /// 处理快捷指令返回的截图数据
    func handleShortcutCallback(url: URL) -> UIImage? {
        print("📥 处理快捷指令回调: \(url)")
        
        // 解析URL参数
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ 无法解析回调URL")
            return nil
        }
        
        // 查找图片数据参数
        for item in queryItems {
            switch item.name {
            case "image_data":
                // Base64编码的图片数据
                if let value = item.value,
                   let imageData = Data(base64Encoded: value),
                   let image = UIImage(data: imageData) {
                    print("✅ 成功解析截图数据")
                    return image
                }
            case "image_path":
                // 图片文件路径
                if let value = item.value,
                   let imageData = try? Data(contentsOf: URL(fileURLWithPath: value)),
                   let image = UIImage(data: imageData) {
                    print("✅ 成功从路径加载截图")
                    return image
                }
            default:
                continue
            }
        }
        
        print("❌ 未找到有效的图片数据")
        return nil
    }
    
    /// 从剪贴板获取截图
    func getScreenshotFromPasteboard() -> UIImage? {
        print("📋 从剪贴板获取截图")
        
        if UIPasteboard.general.hasImages,
           let image = UIPasteboard.general.image {
            print("✅ 从剪贴板成功获取截图")
            return image
        }
        
        print("❌ 剪贴板中没有图片")
        return nil
    }
    
    /// 监听共享文件夹中的新截图
    func monitorSharedContainer() -> URL? {
        print("📁 监听共享容器")
        
        // 获取App Group共享容器
        guard let sharedURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.expensetracker"
        ) else {
            print("❌ 无法访问共享容器")
            return nil
        }
        
        let screenshotsURL = sharedURL.appendingPathComponent("screenshots")
        
        // 创建目录（如果不存在）
        try? FileManager.default.createDirectory(
            at: screenshotsURL,
            withIntermediateDirectories: true
        )
        
        return screenshotsURL
    }
} 