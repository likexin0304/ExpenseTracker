import Foundation
import Combine

/**
 * 网络重试服务 - Phase 3 新增
 * 处理自动识别功能中的网络错误和重试逻辑
 */
class NetworkRetryService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前重试次数
    @Published var currentRetryCount: Int = 0
    
    /// 是否正在重试
    @Published var isRetrying: Bool = false
    
    /// 网络状态
    @Published var networkStatus: NetworkStatus = .unknown
    
    // MARK: - Private Properties
    
    /// 最大重试次数
    private let maxRetryCount: Int = 3
    
    /// 重试延迟（秒）
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 5.0]
    
    /// 网络监控
    private var networkMonitor: NetworkMonitor?
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = NetworkRetryService()
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /**
     * 执行带重试的网络请求
     */
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        retryCondition: @escaping (Error) -> Bool = { _ in true }
    ) async throws -> T {
        
        currentRetryCount = 0
        
        while currentRetryCount <= maxRetryCount {
            do {
                let result = try await operation()
                
                // 成功，重置重试计数
                await MainActor.run {
                    currentRetryCount = 0
                    isRetrying = false
                }
                
                return result
                
            } catch {
                print("🔄 网络请求失败 (尝试 \(currentRetryCount + 1)/\(maxRetryCount + 1)): \(error.localizedDescription)")
                
                // 检查是否应该重试
                if currentRetryCount >= maxRetryCount || !retryCondition(error) {
                    await MainActor.run {
                        isRetrying = false
                    }
                    throw error
                }
                
                // 更新重试状态
                await MainActor.run {
                    currentRetryCount += 1
                    isRetrying = true
                }
                
                // 等待重试延迟
                let delay = retryDelays[min(currentRetryCount - 1, retryDelays.count - 1)]
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw NetworkRetryError.maxRetriesExceeded
    }
    
    /**
     * 检查网络连接
     */
    func checkNetworkConnection() async -> Bool {
        // 简单的网络连接检查
        guard let url = URL(string: "https://www.apple.com") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    /**
     * 重置重试状态
     */
    func resetRetryState() {
        currentRetryCount = 0
        isRetrying = false
    }
    
    /**
     * 获取重试建议
     */
    func getRetryAdvice(for error: Error) -> RetryAdvice {
        if let networkError = error as? URLError {
            switch networkError.code {
            case .notConnectedToInternet:
                return RetryAdvice(
                    shouldRetry: false,
                    message: "请检查网络连接",
                    suggestion: "确保设备已连接到互联网"
                )
            case .timedOut:
                return RetryAdvice(
                    shouldRetry: true,
                    message: "网络超时",
                    suggestion: "网络较慢，建议稍后重试"
                )
            case .cannotFindHost, .cannotConnectToHost:
                return RetryAdvice(
                    shouldRetry: true,
                    message: "服务器连接失败",
                    suggestion: "服务器可能暂时不可用"
                )
            default:
                return RetryAdvice(
                    shouldRetry: true,
                    message: "网络错误",
                    suggestion: "请检查网络设置"
                )
            }
        }
        
        return RetryAdvice(
            shouldRetry: true,
            message: "未知错误",
            suggestion: "请稍后重试"
        )
    }
    
    // MARK: - Private Methods
    
    /**
     * 设置网络监控
     */
    private func setupNetworkMonitoring() {
        networkMonitor = NetworkMonitor()
        
        networkMonitor?.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.networkStatus = status
            }
            .store(in: &cancellables)
        
        networkMonitor?.startMonitoring()
    }
}

/**
 * 网络状态枚举
 */
enum NetworkStatus {
    case unknown
    case connected
    case disconnected
    case cellular
    case wifi
    
    var description: String {
        switch self {
        case .unknown:
            return "未知"
        case .connected:
            return "已连接"
        case .disconnected:
            return "未连接"
        case .cellular:
            return "蜂窝网络"
        case .wifi:
            return "WiFi"
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .connected, .cellular, .wifi:
            return true
        default:
            return false
        }
    }
}

/**
 * 重试建议
 */
struct RetryAdvice {
    let shouldRetry: Bool
    let message: String
    let suggestion: String
}

/**
 * 网络重试错误
 */
enum NetworkRetryError: LocalizedError {
    case maxRetriesExceeded
    case networkUnavailable
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "已达到最大重试次数"
        case .networkUnavailable:
            return "网络不可用"
        case .invalidResponse:
            return "无效的服务器响应"
        }
    }
}

/**
 * 网络监控器
 */
class NetworkMonitor: ObservableObject {
    
    private let statusSubject = CurrentValueSubject<NetworkStatus, Never>(.unknown)
    
    var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    func startMonitoring() {
        // 简化的网络监控实现
        // 在真实应用中，这里应该使用Network框架
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkNetworkStatus()
        }
    }
    
    private func checkNetworkStatus() {
        Task {
            let isConnected = await NetworkRetryService.shared.checkNetworkConnection()
            await MainActor.run {
                statusSubject.send(isConnected ? .connected : .disconnected)
            }
        }
    }
}

/**
 * 网络重试服务扩展 - 自动识别专用
 */
extension NetworkRetryService {
    
    /**
     * OCR服务重试
     */
    func retryOCRRequest<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await executeWithRetry(operation: operation) { error in
            // OCR服务特定的重试条件
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    return false // 不重试网络连接问题
                case .timedOut, .cannotConnectToHost:
                    return true // 重试超时和连接问题
                default:
                    return true
                }
            }
            return true
        }
    }
    
    /**
     * 数据解析服务重试
     */
    func retryDataParsingRequest<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await executeWithRetry(operation: operation) { error in
            // 数据解析服务特定的重试条件
            return !(error is DecodingError) // 不重试解码错误
        }
    }
} 