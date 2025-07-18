//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by 李可心(Daniel.L) on 2025/6/9.
//

import SwiftUI
import BackgroundTasks
import Foundation
import UIKit

// Add direct import for AutoOCRService
@_exported import struct Foundation.UUID
@_exported import class UIKit.UIImage
@_exported import class Foundation.JSONEncoder
@_exported import class Foundation.JSONDecoder

// Add a helper function to access AutoOCRService
func getAutoOCRService() -> Any {
    // This is a workaround to access AutoOCRService without direct import
    let namespace = Bundle.main.infoDictionary!["CFBundleExecutable"] as! String
    let className = "\(namespace).AutoOCRService"
    let autoOCRServiceClass = NSClassFromString(className) as! NSObject.Type
    return autoOCRServiceClass.value(forKeyPath: "shared")!
}

@main
struct ExpenseTrackerApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // 注册后台任务
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundTask()
                }
        }
    }
    
    // MARK: - URL处理
    
    /// 处理传入的URL
    private func handleIncomingURL(_ url: URL) {
        print("📥 收到URL回调: \(url)")
        
        guard url.scheme == "expensetracker" else {
            print("❌ 不支持的URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "auto-ocr":
            // 处理自动OCR请求
            handleAutoOCRRequest(url)
        case "process-screenshot":
            // 处理截图处理请求
            handleScreenshotProcessing(url)
        default:
            print("❌ 不支持的URL host: \(url.host ?? "nil")")
        }
    }
    
    /// 处理自动OCR请求
    private func handleAutoOCRRequest(_ url: URL) {
        print("🤖 处理自动OCR请求")
        
        Task {
            // 确保在主线程执行
            await MainActor.run {
                // 触发自动OCR服务
                let autoOCRService = getAutoOCRService()
                if (autoOCRService as AnyObject).value(forKey: "isEnabled") as! Bool {
                    Task {
                        _ = try? await (autoOCRService as AnyObject).value(forKey: "handleBackgroundTrigger")
                    }
                } else {
                    print("⚠️ 自动OCR服务未启用")
                }
            }
        }
    }
    
    /// 处理截图处理请求
    private func handleScreenshotProcessing(_ url: URL) {
        print("📷 处理截图处理请求")
        
        Task {
            await MainActor.run {
                // 通知自动OCR服务处理剪贴板中的截图
                NotificationCenter.default.post(
                    name: NSNotification.Name("ProcessClipboardScreenshot"),
                    object: nil,
                    userInfo: ["sourceURL": url]
                )
            }
        }
    }
    
    // MARK: - 后台任务管理
    
    /// 注册后台任务
    private func registerBackgroundTasks() {
        print("📋 注册后台任务")
        
        // 注册后台处理任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.expensetracker.background-ocr", using: nil) { task in
            handleBackgroundOCRTask(task as! BGProcessingTask)
        }
        
        // 注册后台刷新任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.expensetracker.background-refresh", using: nil) { task in
            handleBackgroundRefreshTask(task as! BGAppRefreshTask)
        }
    }
    
    /// 调度后台任务
    private func scheduleBackgroundTask() {
        print("⏰ 调度后台任务")
        
        // 调度后台处理任务
        let processingRequest = BGProcessingTaskRequest(identifier: "com.expensetracker.background-ocr")
        processingRequest.requiresNetworkConnectivity = true
        processingRequest.requiresExternalPower = false
        processingRequest.earliestBeginDate = Date(timeIntervalSinceNow: 1) // 1秒后开始
        
        do {
            try BGTaskScheduler.shared.submit(processingRequest)
            print("✅ 后台处理任务已调度")
        } catch {
            print("❌ 调度后台处理任务失败: \(error)")
        }
        
        // 调度后台刷新任务
        let refreshRequest = BGAppRefreshTaskRequest(identifier: "com.expensetracker.background-refresh")
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 5) // 5秒后开始
        
        do {
            try BGTaskScheduler.shared.submit(refreshRequest)
            print("✅ 后台刷新任务已调度")
        } catch {
            print("❌ 调度后台刷新任务失败: \(error)")
        }
    }
    
    /// 处理后台OCR任务
    private func handleBackgroundOCRTask(_ task: BGProcessingTask) {
        print("🔄 执行后台OCR任务")
        
        task.expirationHandler = {
            print("⏰ 后台OCR任务即将过期")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // 检查是否有待处理的截图
                let autoOCRService = getAutoOCRService()
                if (autoOCRService as AnyObject).value(forKey: "isEnabled") as! Bool {
                    _ = try? await (autoOCRService as AnyObject).value(forKey: "checkForPendingScreenshots")
                }
                
                print("✅ 后台OCR任务完成")
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ 后台OCR任务失败: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    /// 处理后台刷新任务
    private func handleBackgroundRefreshTask(_ task: BGAppRefreshTask) {
        print("🔄 执行后台刷新任务")
        
        task.expirationHandler = {
            print("⏰ 后台刷新任务即将过期")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            // 这里可以执行一些轻量级的后台刷新操作
            print("✅ 后台刷新任务完成")
            task.setTaskCompleted(success: true)
        }
    }
}
