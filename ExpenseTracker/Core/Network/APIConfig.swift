import Foundation

/**
 * API配置
 * 包含API相关的配置信息
 */
struct APIConfig {
    // 🌐 环境配置 - 使用生产环境
    static let isProduction = true // 使用生产环境
    
    // 📍 API 服务器配置 - 更新为最新的生产环境URL
    private static let developmentURL = "http://192.168.1.100:3000" // 将替换为实际的局域网IP
    private static let productionURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            return "https://expense-tracker-backend-1mnvyo1le-likexin0304s-projects.vercel.app"
        }
        return url
    }()
    
    static let baseURL = isProduction ? productionURL : developmentURL
    static let timeout: TimeInterval = 30.0
    
    // ✅ 统一的API端点枚举（匹配后端API文档）
    enum Endpoint: String, CaseIterable {
        // 🏥 健康检查
        case health = "/health"
        case debugRoutes = "/api/debug/routes"
        
        // 🔐 认证相关
        case authRegister = "/api/auth/register"
        case authLogin = "/api/auth/login"
        case authMe = "/api/auth/me"
        case authDeleteAccount = "/api/auth/account"
        case authDebugUsers = "/api/auth/debug/users"
        
        // 💰 预算相关
        case budgetSet = "/api/budget"
        case budgetCurrent = "/api/budget/current"
        case budgetAlerts = "/api/budget/alerts"
        case budgetSuggestions = "/api/budget/suggestions"
        case budgetHistory = "/api/budget/history"
        // 动态路径端点将在fullURL方法中处理
        
        // 💸 支出相关
        case expense = "/api/expense" // POST创建, GET获取列表
        case expenseStats = "/api/expense/stats"
        case expenseCategories = "/api/expense/categories"
        case expenseExport = "/api/expense/export"
        case expenseTrends = "/api/expense/trends"
        // 动态路径端点将在fullURL方法中处理
        
        // 🤖 OCR相关
        case ocrParse = "/api/ocr/parse"
        case ocrParseAuto = "/api/ocr/parse-auto"
        case ocrRecords = "/api/ocr/records"
        case ocrStatistics = "/api/ocr/statistics"
        case ocrMerchants = "/api/ocr/merchants"
        case ocrMerchantsMatch = "/api/ocr/merchants/match"
        case ocrShortcuts = "/api/ocr/shortcuts/generate"
        // 动态路径端点将在fullURL方法中处理
        
        /// 构建完整URL
        var fullURL: String {
            return APIConfig.baseURL + self.rawValue
        }
        
        /// 构建带路径参数的完整URL
        func fullURL(with pathComponent: String) -> String {
            switch self {
            // 预算相关动态路径
            case .budgetSet where pathComponent.contains("/"):
                // 处理 /api/budget/:year/:month 格式
                return APIConfig.baseURL + "/api/budget/\(pathComponent)"
            case .budgetSet:
                // 处理 /api/budget/:budgetId 格式
                return APIConfig.baseURL + "/api/budget/\(pathComponent)"
                
            // 支出相关动态路径
            case .expense:
                // 处理 /api/expense/:id 格式
                return APIConfig.baseURL + "/api/expense/\(pathComponent)"
                
            // OCR相关动态路径
            case .ocrRecords:
                // 处理 /api/ocr/records/:recordId 格式
                return APIConfig.baseURL + "/api/ocr/records/\(pathComponent)"
            case .ocrParse:
                // 处理 /api/ocr/confirm/:recordId 格式
                return APIConfig.baseURL + "/api/ocr/confirm/\(pathComponent)"
                
            default:
                return APIConfig.baseURL + self.rawValue + "/\(pathComponent)"
            }
        }
    }
    
    // 🔧 Supabase 配置
    struct Supabase {
        static let url: String = {
            guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
                fatalError("❌ 无法从 Info.plist 获取 SUPABASE_URL")
            }
            return url
        }()
        
        static let anonKey: String = {
            guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
                fatalError("❌ 无法从 Info.plist 获取 SUPABASE_ANON_KEY")
            }
            return key
        }()
    }
    
    // 调试信息
    static func debugInfo() {
        print("🌐 === API 配置信息 ===")
        print("🏗️ 环境: \(isProduction ? "生产环境" : "开发环境")")
        print("📍 Base URL: \(baseURL)")
        print("⏱️ Timeout: \(timeout)秒")
        print("🌐 Supabase URL: \(Supabase.url)")
        print("🔑 Supabase Anon Key: \(String(Supabase.anonKey.prefix(20)))...")
        print("🔗 API Endpoints: \(Endpoint.allCases.count)个")
        print("🌐 =====================")
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}
