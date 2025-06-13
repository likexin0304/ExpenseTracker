import UIKit
import Combine

/**
 * 屏幕截图服务
 * 负责捕获当前屏幕内容用于OCR识别
 */
class ScreenCaptureService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 权限状态
    @Published var permissionStatus: PermissionStatus = .notDetermined
    
    /// 是否正在截图
    @Published var isCapturing: Bool = false
    
    // MARK: - Private Properties
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = ScreenCaptureService()
    
    private init() {
        checkPermissionStatus()
    }
    
    // MARK: - Public Methods
    
    /**
     * 请求屏幕录制权限
     */
    func requestPermission() async -> Bool {
        print("🔄 请求屏幕录制权限")
        
        // 检查系统版本
        guard #available(iOS 11.0, *) else {
            print("❌ 系统版本过低，不支持屏幕录制")
            await MainActor.run {
                permissionStatus = .notSupported
            }
            return false
        }
        
        return await withCheckedContinuation { continuation in
            // 在iOS中，屏幕录制权限需要通过系统设置手动开启
            // 这里我们检查是否可以进行屏幕截图
            Task { @MainActor in
                self.checkPermissionStatus()
                let hasPermission = self.permissionStatus == .authorized
                continuation.resume(returning: hasPermission)
            }
        }
    }
    
    /**
     * 捕获当前屏幕
     */
    func captureScreen() async -> UIImage? {
        print("🔄 开始捕获屏幕")
        
        await MainActor.run {
            isCapturing = true
        }
        
        defer {
            Task { @MainActor in
                isCapturing = false
            }
        }
        
        // 检查权限
        guard permissionStatus == .authorized else {
            print("❌ 没有屏幕录制权限")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let image = self.captureCurrentScreen()
                continuation.resume(returning: image)
            }
        }
    }
    
    /**
     * 检查权限状态
     */
    func checkPermissionStatus() {
        print("🔄 检查屏幕录制权限状态")
        
        // 在iOS中，我们通过尝试截图来检查权限
        // 如果能成功截图，说明有权限
        Task { @MainActor in
            if self.canCaptureScreen() {
                self.permissionStatus = .authorized
                print("✅ 有屏幕录制权限")
            } else {
                self.permissionStatus = .denied
                print("❌ 没有屏幕录制权限")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * 检查是否可以截图
     */
    private func canCaptureScreen() -> Bool {
        // 尝试获取主窗口
        guard let window = getKeyWindow() else {
            return false
        }
        
        // 检查窗口是否可见
        return !window.isHidden && window.alpha > 0
    }
    
    /**
     * 获取主窗口
     */
    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
    
    /**
     * 捕获当前屏幕的实际实现
     */
    private func captureCurrentScreen() -> UIImage? {
        print("📸 执行屏幕截图")
        
        guard let window = getKeyWindow() else {
            print("❌ 无法获取主窗口")
            return nil
        }
        
        let bounds = window.bounds
        
        // 创建图形上下文
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ 无法创建图形上下文")
            return nil
        }
        
        // 渲染窗口内容到上下文
        window.layer.render(in: context)
        
        // 获取截图
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        
        if screenshot != nil {
            print("✅ 屏幕截图成功，尺寸: \(bounds.size)")
        } else {
            print("❌ 屏幕截图失败")
        }
        
        return screenshot
    }
    
    /**
     * 捕获指定视图
     */
    func captureView(_ view: UIView) -> UIImage? {
        print("📸 捕获指定视图")
        
        let bounds = view.bounds
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ 无法创建图形上下文")
            return nil
        }
        
        view.layer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        if image != nil {
            print("✅ 视图截图成功")
        } else {
            print("❌ 视图截图失败")
        }
        
        return image
    }
    
    /**
     * 保存截图到相册（调试用）
     */
    func saveScreenshotToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        print("💾 截图已保存到相册")
    }
}

/**
 * 屏幕截图配置
 */
struct ScreenCaptureConfiguration {
    /// 截图质量
    var quality: CGFloat = 1.0
    
    /// 是否包含状态栏
    var includeStatusBar: Bool = true
    
    /// 是否保存到相册（调试用）
    var saveToPhotos: Bool = false
    
    /// 截图延迟（秒）
    var captureDelay: TimeInterval = 0.0
}

/**
 * 屏幕截图结果
 */
struct ScreenCaptureResult {
    /// 截图图像
    let image: UIImage
    
    /// 截图时间
    let timestamp: Date
    
    /// 图像尺寸
    let size: CGSize
    
    /// 截图质量
    let quality: CGFloat
    
    init(image: UIImage, quality: CGFloat = 1.0) {
        self.image = image
        self.timestamp = Date()
        self.size = image.size
        self.quality = quality
    }
} 