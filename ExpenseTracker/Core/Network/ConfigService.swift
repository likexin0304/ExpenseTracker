import Foundation
import Combine

/**
 * 动态配置服务
 * 从后端获取最新的API配置，避免硬编码URL导致的问题
 * 
 * 功能特性：
 * - 🔄 自动从后端同步最新配置
 * - 💾 本地缓存配置，支持离线使用
 * - 🔃 降级机制：后端不可用时使用缓存或默认配置
 * - ⚡️ 应用启动时自动更新配置
 */
class ConfigService {
    // MARK: - 单例
    static let shared = ConfigService()
    
    // MARK: - 配置模型
    struct APIConfiguration: Codable {
        let baseURL: String
        let supabaseURL: String
        let version: String
        let endpoints: [String: String]?
        let lastUpdated: Date
        
        enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case supabaseURL = "supabase_url"
            case version
            case endpoints
            case lastUpdated = "last_updated"
        }
    }
    
    // MARK: - 属性
    private let userDefaults = UserDefaults.standard
    private let configCacheKey = "api_configuration_cache"
    private let lastSyncKey = "api_configuration_last_sync"
    
    // 配置更新发布者
    let configurationUpdated = PassthroughSubject<APIConfiguration, Never>()
    
    // 当前配置（从缓存或默认值加载）
    private(set) var currentConfiguration: APIConfiguration
    
    // 默认配置（作为降级方案）
    private let defaultConfiguration = APIConfiguration(
        baseURL: "https://expense-tracker-backend-likexin0304s-projects.vercel.app",
        supabaseURL: "https://nlrtjnvwgsaavtpfccxg.supabase.co",
        version: "1.0.0",
        endpoints: nil,
        lastUpdated: Date()
    )
    
    // MARK: - 初始化
    private init() {
        // 先初始化 currentConfiguration 为默认配置
        self.currentConfiguration = defaultConfiguration
        
        // 然后尝试加载缓存配置
        if let cachedConfig = Self.loadCachedConfigurationStatic() {
            self.currentConfiguration = cachedConfig
            print("🔧 ConfigService: 已加载缓存配置")
        } else {
            print("🔧 ConfigService: 使用默认配置")
        }
    }
    
    // MARK: - 公共方法
    
    /// 获取当前的baseURL
    var baseURL: String {
        return currentConfiguration.baseURL
    }
    
    /// 获取当前的Supabase URL
    var supabaseURL: String {
        return currentConfiguration.supabaseURL
    }
    
    /// 从后端同步最新配置
    /// - Parameter completion: 完成回调，返回是否成功
    func syncConfiguration(completion: @escaping (Result<APIConfiguration, Error>) -> Void) {
        print("🔄 ConfigService: 开始同步配置...")
        
        // 尝试多个配置端点
        let configEndpoints = [
            "\(currentConfiguration.baseURL)/api/config",
            "\(defaultConfiguration.baseURL)/api/config"
        ]
        
        tryFetchConfiguration(from: configEndpoints, completion: completion)
    }
    
    /// 强制刷新配置（用户手动触发）
    func forceRefresh(completion: @escaping (Result<APIConfiguration, Error>) -> Void) {
        print("🔃 ConfigService: 强制刷新配置...")
        syncConfiguration(completion: completion)
    }
    
    /// 重置为默认配置
    func resetToDefault() {
        print("⚠️ ConfigService: 重置为默认配置")
        currentConfiguration = defaultConfiguration
        saveConfiguration(defaultConfiguration)
        configurationUpdated.send(defaultConfiguration)
    }
    
    /// 检查是否需要更新配置（超过24小时）
    func shouldSync() -> Bool {
        guard let lastSync = userDefaults.object(forKey: lastSyncKey) as? Date else {
            return true
        }
        let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceLastSync >= 24
    }
    
    // MARK: - 私有方法
    
    /// 尝试从多个端点获取配置
    private func tryFetchConfiguration(from endpoints: [String], completion: @escaping (Result<APIConfiguration, Error>) -> Void) {
        guard !endpoints.isEmpty else {
            print("❌ ConfigService: 所有配置端点都已尝试，使用降级方案")
            completion(.failure(ConfigError.allEndpointsFailed))
            return
        }
        
        var remainingEndpoints = endpoints
        let endpoint = remainingEndpoints.removeFirst()
        
        fetchConfiguration(from: endpoint) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let config):
                // 成功获取配置
                self.currentConfiguration = config
                self.saveConfiguration(config)
                self.configurationUpdated.send(config)
                completion(.success(config))
                print("✅ ConfigService: 配置同步成功 - \(config.baseURL)")
                
            case .failure(let error):
                print("⚠️ ConfigService: 端点 \(endpoint) 失败: \(error.localizedDescription)")
                // 尝试下一个端点
                if !remainingEndpoints.isEmpty {
                    self.tryFetchConfiguration(from: remainingEndpoints, completion: completion)
                } else {
                    // 所有端点都失败，使用缓存或默认配置
                    print("⚠️ ConfigService: 所有端点失败，使用当前配置")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 从指定端点获取配置
    private func fetchConfiguration(from endpoint: String, completion: @escaping (Result<APIConfiguration, Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(ConfigError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10 // 10秒超时
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ConfigError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(ConfigError.httpError(statusCode: httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ConfigError.noData))
                return
            }
            
            do {
                // 尝试解析标准响应格式
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // 先尝试解析包装格式
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = jsonObject["success"] as? Bool,
                   success,
                   let configData = jsonObject["data"] as? [String: Any] {
                    let configJSON = try JSONSerialization.data(withJSONObject: configData)
                    var config = try decoder.decode(APIConfiguration.self, from: configJSON)
                    config = APIConfiguration(
                        baseURL: config.baseURL,
                        supabaseURL: config.supabaseURL,
                        version: config.version,
                        endpoints: config.endpoints,
                        lastUpdated: Date()
                    )
                    completion(.success(config))
                } else {
                    // 直接解析配置对象
                    var config = try decoder.decode(APIConfiguration.self, from: data)
                    config = APIConfiguration(
                        baseURL: config.baseURL,
                        supabaseURL: config.supabaseURL,
                        version: config.version,
                        endpoints: config.endpoints,
                        lastUpdated: Date()
                    )
                    completion(.success(config))
                }
            } catch {
                completion(.failure(ConfigError.decodingError(error)))
            }
        }.resume()
    }
    
    /// 保存配置到本地缓存
    private func saveConfiguration(_ config: APIConfiguration) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: configCacheKey)
            userDefaults.set(Date(), forKey: lastSyncKey)
            print("💾 ConfigService: 配置已缓存")
        } catch {
            print("❌ ConfigService: 缓存配置失败 - \(error.localizedDescription)")
        }
    }
    
    /// 从本地缓存加载配置（静态方法，用于初始化时调用）
    private static func loadCachedConfigurationStatic() -> APIConfiguration? {
        let userDefaults = UserDefaults.standard
        let configCacheKey = "api_configuration_cache"
        
        guard let data = userDefaults.data(forKey: configCacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(APIConfiguration.self, from: data)
            return config
        } catch {
            print("❌ ConfigService: 加载缓存配置失败 - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从本地缓存加载配置（实例方法）
    private func loadCachedConfiguration() -> APIConfiguration? {
        return Self.loadCachedConfigurationStatic()
    }
    
    // MARK: - 调试信息
    func printDebugInfo() {
        print("🔧 === ConfigService 调试信息 ===")
        print("📍 当前 Base URL: \(currentConfiguration.baseURL)")
        print("🌐 当前 Supabase URL: \(currentConfiguration.supabaseURL)")
        print("📦 配置版本: \(currentConfiguration.version)")
        print("📅 最后更新: \(currentConfiguration.lastUpdated)")
        
        if let lastSync = userDefaults.object(forKey: lastSyncKey) as? Date {
            let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
            print("⏰ 上次同步: \(String(format: "%.1f", hoursSinceSync)) 小时前")
        } else {
            print("⏰ 上次同步: 从未")
        }
        
        print("🔧 ================================")
    }
}

// MARK: - 错误定义
enum ConfigError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case httpError(statusCode: Int)
    case decodingError(Error)
    case allEndpointsFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "配置URL无效"
        case .invalidResponse:
            return "服务器响应无效"
        case .noData:
            return "没有接收到数据"
        case .httpError(let statusCode):
            return "HTTP错误: \(statusCode)"
        case .decodingError(let error):
            return "解析配置失败: \(error.localizedDescription)"
        case .allEndpointsFailed:
            return "所有配置端点都不可用"
        }
    }
}

