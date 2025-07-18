import Foundation
import UIKit

/// 简化的快捷指令服务
class SimpleShortcutService: ObservableObject {
    static let shared = SimpleShortcutService()
    
    @Published var isShortcutInstalled = false
    @Published var shortcutError: String?
    
    private let shortcutName = "ExpenseTracker自动记账"
    
    private init() {
        print("📱 SimpleShortcutService初始化")
        checkShortcutInstallation()
    }
    
    /// 检查快捷指令是否已安装
    func checkShortcutInstallation() {
        print("🔍 检查快捷指令安装状态")
        
        // 简单检查快捷指令应用是否可用
        let shortcutsURL = URL(string: "shortcuts://")!
        
        DispatchQueue.main.async {
            self.isShortcutInstalled = UIApplication.shared.canOpenURL(shortcutsURL)
            print(self.isShortcutInstalled ? "✅ 快捷指令应用可用" : "❌ 快捷指令应用不可用")
        }
    }
    
    /// 创建快捷指令（引导用户手动创建）
    func createShortcut() async throws {
        print("🛠️ 引导用户创建快捷指令")
        
        await MainActor.run {
            shortcutError = nil
        }
        
        // 显示创建指导信息
        await showShortcutCreationGuide()
        
        // 打开快捷指令应用
        let shortcutsURL = URL(string: "shortcuts://")!
        
        await MainActor.run {
            if UIApplication.shared.canOpenURL(shortcutsURL) {
                UIApplication.shared.open(shortcutsURL) { success in
                    if success {
                        print("✅ 快捷指令应用已打开")
                        self.isShortcutInstalled = true
                    } else {
                        print("❌ 无法打开快捷指令应用")
                        self.shortcutError = "无法打开快捷指令应用"
                    }
                }
            } else {
                self.shortcutError = "设备不支持快捷指令"
            }
        }
    }
    
    /// 显示快捷指令创建指导
    private func showShortcutCreationGuide() async {
        print("📖 显示快捷指令创建指导")
        
        // 这里可以触发显示指导界面或弹窗
        // 由于这是一个服务类，我们通过通知来告知UI显示指导
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowShortcutCreationGuide"),
                object: nil,
                userInfo: ["instructions": getShortcutInstructions()]
            )
        }
    }
    
    /// 触发快捷指令
    func triggerShortcut() async throws {
        print("🚀 触发快捷指令")
        
        guard isShortcutInstalled else {
            throw ShortcutError.notInstalled
        }
        
        // 构建快捷指令URL（如果用户已创建同名快捷指令）
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let shortcutURL = URL(string: "shortcuts://run-shortcut?name=\(encodedName)")
        
        await MainActor.run {
            if let url = shortcutURL, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ 快捷指令触发成功")
                    } else {
                        print("❌ 快捷指令触发失败")
                        self.shortcutError = "快捷指令执行失败"
                    }
                }
            } else {
                self.shortcutError = "快捷指令不存在，请先创建"
            }
        }
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
    
    /// 获取快捷指令模板说明
    func getShortcutInstructions() -> [String] {
        return [
            "1. 打开iPhone的\"快捷指令\"应用",
            "2. 点击右上角\"+\"创建新快捷指令",
            "3. 搜索并添加\"拍摄屏幕快照\"操作",
            "4. 添加\"拷贝到剪贴板\"操作",
            "5. 添加\"打开URL\"操作（注意：是\"打开URL\"不是\"打开App\"）",
            "6. 在URL字段中输入：expensetracker://process-screenshot",
            "7. 将快捷指令命名为\"ExpenseTracker自动记账\"",
            "8. 保存快捷指令",
            "9. 打开iPhone\"设置\" → \"辅助功能\" → \"触控\" → \"背面轻点\"",
            "10. 选择\"轻点三下\"，然后选择运行\"ExpenseTracker自动记账\"快捷指令"
        ]
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
    
    /// 处理快捷指令回调（简化版本）
    func handleShortcutCallback(url: URL) -> UIImage? {
        print("📥 处理快捷指令回调: \(url)")
        
        // 简化处理：直接从剪贴板获取
        return getScreenshotFromPasteboard()
    }
}

/// 简化的快捷指令错误类型
enum ShortcutError: LocalizedError {
    case notInstalled
    case invalidURL
    case executionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "快捷指令未安装"
        case .invalidURL:
            return "无效的快捷指令URL"
        case .executionFailed:
            return "快捷指令执行失败"
        }
    }
} 