import Foundation
import Combine

/// OCR API服务
class OCRAPIService: ObservableObject {
    static let shared = OCRAPIService()
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    /// OCR服务可用状态缓存
    private var serviceAvailabilityCache: Bool? = nil
    /// 缓存过期时间（秒）
    private let cacheExpirationTime: TimeInterval = 300 // 5分钟
    /// 上次检查时间
    private var lastCheckTime: Date? = nil
    
    private init() {
        print("🔍 OCRAPIService初始化")
    }
    
    // MARK: - OCR解析API
    
    /// 解析OCR文本
    /// - Parameter text: 要解析的文本
    /// - Returns: 解析结果
    func parseOCRText(_ text: String) -> AnyPublisher<OCRParseData, NetworkError> {
        print("🔍 解析OCR文本: \(text.prefix(50))...")
        
        let request = OCRParseRequest(text: text)
        
        // 🔧 先尝试旧格式OCRParseResponse，如果失败再尝试新格式
        return networkManager.request(
            endpoint: .ocrParse,
            method: .POST,
            body: request,
            responseType: OCRParseResponse.self
        )
        .tryMap { response -> OCRParseData in
            // 🆕 首先检查success字段
            guard response.success else {
                print("❌ OCR解析失败 (旧格式): \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "OCR解析失败")
            }
            
            // 🆕 验证data字段是否存在
            guard let data = response.data else {
                print("❌ OCR响应数据缺失 (旧格式)")
                throw NetworkError.serverError("响应数据缺失")
            }
            
            print("✅ OCR解析成功 (旧格式): 商户=\(data.record.parsedData.merchant?.name ?? "未知"), 金额=\(data.record.parsedData.amount?.value ?? 0)")
            return data
        }
        .mapError { error -> NetworkError in
            // 🔧 特殊处理OCR服务不可用的情况
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR服务暂时不可用")
                    // 更新服务可用性缓存
                    self.updateServiceAvailabilityCache(isAvailable: false)
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 解析文本
    /// - Parameter text: 要解析的文本
    /// - Returns: 解析结果
    func parseText(_ text: String) -> AnyPublisher<OCRParseResponse, NetworkError> {
        print("📝 解析文本: \(text.prefix(50))...")
        
        let request = OCRParseRequest(text: text)
        
        return networkManager.request(
            endpoint: .ocrParse,
            method: .POST,
            body: request,
            responseType: OCRParseResponse.self
        )
        .mapError { error -> NetworkError in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR文本解析服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 处理图像
    /// - Parameter image: 要处理的图像
    /// - Returns: 处理结果
    func processImage(_ image: UIImage) -> AnyPublisher<OCRParseResponse, NetworkError> {
        print("🖼️ 处理图像...")
        
        // 模拟图像处理结果
        let mockMerchant = OCRMerchant(name: "星巴克", confidence: 0.95)
        let mockAmount = OCRAmount(value: 35.50, currency: "CNY", confidence: 0.98)
        let mockDate = OCRDate(value: "2024-01-15T14:30:00Z", confidence: 0.9)
        let mockPaymentMethod = OCRPaymentMethod(type: "支付宝", confidence: 0.85)
        let mockCategory = OCRCategory(name: "餐饮", confidence: 0.8)
        
        let mockParsedData = OCRParsedData(
            merchant: mockMerchant,
            amount: mockAmount,
            date: mockDate,
            paymentMethod: mockPaymentMethod,
            category: mockCategory
        )
        
        let mockSuggestions = OCRSuggestions(
            autoCreate: true,
            needsReview: false,
            confidence: "高"
        )
        
        let mockRecord = OCRRecord(
            id: "mock_record_123",
            originalText: "星巴克 ¥35.50 支付宝",
            parsedData: mockParsedData,
            confidenceScore: 0.85,
            status: "已解析",
            suggestions: mockSuggestions,
            expenseId: nil,
            errorMessage: nil,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let mockParseData = OCRParseData(record: mockRecord)
        let mockResponse = OCRParseResponse(success: true, data: mockParseData, message: nil)
        
        // 延迟返回模拟数据，模拟网络延迟
        return Just(mockResponse)
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .setFailureType(to: NetworkError.self)
            .eraseToAnyPublisher()
    }
    
    /// 检查OCR服务状态
    /// - Returns: 服务是否可用
    func checkServiceAvailability() -> AnyPublisher<Bool, Never> {
        print("🔍 检查OCR服务可用性...")
        
        // 如果缓存有效，直接返回缓存结果
        if let cachedAvailability = getCachedServiceAvailability() {
            print("📋 使用缓存的OCR服务可用性结果: \(cachedAvailability ? "可用" : "不可用")")
            return Just(cachedAvailability).eraseToAnyPublisher()
        }
        
        // 创建一个简单的请求体
        let testRequest = OCRParseRequest(text: "test")
        
        // 简单的健康检查，尝试访问OCR端点
        return networkManager.request(
            endpoint: .ocrParse,
            method: .POST,
            body: testRequest,
            responseType: APIResponse<OCRParseData>.self
        )
        .map { _ in 
            print("✅ OCR服务可用")
            // 更新服务可用性缓存
            self.updateServiceAvailabilityCache(isAvailable: true)
            return true 
        }
        .catch { error -> AnyPublisher<Bool, Never> in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR服务不可用: \(message)")
                    // 更新服务可用性缓存
                    self.updateServiceAvailabilityCache(isAvailable: false)
                    return Just(false).eraseToAnyPublisher()
                }
                
                // 其他服务器错误，可能是服务存在但有问题
                print("⚠️ OCR服务存在但可能有问题: \(networkError.localizedDescription)")
                // 不更新缓存，因为这是临时错误
                return Just(true).eraseToAnyPublisher()
            }
            
            // 网络连接问题，不确定服务是否可用
            print("❓ 无法确定OCR服务可用性: \(error.localizedDescription)")
            return Just(false).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取缓存的服务可用性状态
    private func getCachedServiceAvailability() -> Bool? {
        guard let lastCheckTime = lastCheckTime,
              let cachedAvailability = serviceAvailabilityCache else {
            return nil
        }
        
        // 检查缓存是否过期
        let elapsed = Date().timeIntervalSince(lastCheckTime)
        if elapsed < cacheExpirationTime {
            return cachedAvailability
        }
        
        return nil
    }
    
    /// 更新服务可用性缓存
    private func updateServiceAvailabilityCache(isAvailable: Bool) {
        serviceAvailabilityCache = isAvailable
        lastCheckTime = Date()
        print("📝 更新OCR服务可用性缓存: \(isAvailable ? "可用" : "不可用")")
    }
    
    /// 强制刷新服务可用性状态
    func refreshServiceAvailability() -> AnyPublisher<Bool, Never> {
        // 清除缓存
        serviceAvailabilityCache = nil
        lastCheckTime = nil
        print("🔄 强制刷新OCR服务可用性状态")
        
        // 重新检查
        return checkServiceAvailability()
    }
    
    // MARK: - OCR自动处理API
    
    /// 自动处理OCR文本
    /// - Parameter text: 要处理的文本
    /// - Returns: 处理结果
    func autoProcessOCRText(_ text: String) -> AnyPublisher<OCRProcessResult, NetworkError> {
        print("🤖 自动处理OCR文本: \(text.prefix(50))...")
        
        // 首先检查OCR服务是否可用
        if let cachedAvailability = getCachedServiceAvailability(), !cachedAvailability {
            print("🚫 OCR服务不可用，直接返回错误")
            return Fail(error: NetworkError.ocrServiceUnavailable).eraseToAnyPublisher()
        }
        
        // 创建模拟数据而不是调用真实API
        let mockMerchant = OCRMerchant(name: "星巴克", confidence: 0.95)
        let mockAmount = OCRAmount(value: 35.50, currency: "CNY", confidence: 0.98)
        let mockDate = OCRDate(value: "2024-01-15T14:30:00Z", confidence: 0.9)
        let mockPaymentMethod = OCRPaymentMethod(type: "支付宝", confidence: 0.85)
        let mockCategory = OCRCategory(name: "餐饮", confidence: 0.8)
        
        let mockParsedData = OCRParsedData(
            merchant: mockMerchant,
            amount: mockAmount,
            date: mockDate,
            paymentMethod: mockPaymentMethod,
            category: mockCategory
        )
        
        let mockSuggestions = OCRSuggestions(
            autoCreate: true,
            needsReview: false,
            confidence: "高"
        )
        
        let mockRecord = OCRRecord(
            id: "mock_record_123",
            originalText: text,
            parsedData: mockParsedData,
            confidenceScore: 0.85,
            status: "已解析",
            suggestions: mockSuggestions,
            expenseId: nil,
            errorMessage: nil,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let mockExpense = ExpenseResponse(
            id: "mock_expense_123",
            amount: 35.50,
            category: "food",
            description: "星巴克咖啡",
            date: Date(),
            location: "北京市朝阳区",
            paymentMethod: "alipay",
            tags: ["咖啡", "工作"],
            userId: "user123",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let mockResult = OCRProcessResult(
            record: mockRecord,
            expense: mockExpense,
            autoConfirmed: false
        )
        
        // 延迟返回模拟数据，模拟网络延迟
        return Just(mockResult)
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .setFailureType(to: NetworkError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - OCR确认API
    
    /// 确认OCR记录
    /// - Parameters:
    ///   - recordId: OCR记录ID
    ///   - corrections: 修正数据
    /// - Returns: 确认结果
    func confirmOCRRecord(recordId: String, corrections: [String: Any]? = nil) -> AnyPublisher<ExpenseResponse, NetworkError> {
        print("✅ 确认OCR记录: recordId=\(recordId)")
        
        let request = OCRConfirmRequest(confirmed: true, corrections: corrections)
        
        // 🆕 使用新的带路径参数的方法
        return networkManager.request(
            endpoint: .ocrRecords,
            pathComponent: "\(recordId)/confirm",
            method: .POST,
            body: request,
            responseType: OCRConfirmResponse.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ OCR确认失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "OCR确认失败")
            }
            print("✅ OCR确认成功，支出记录已创建: expenseId=\(response.data.expense.id)")
            return response.data.expense
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR确认服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - OCR记录管理API
    
    /// 获取OCR记录列表
    /// - Parameters:
    ///   - page: 页码
    ///   - limit: 每页数量
    ///   - status: 状态筛选
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: OCR记录列表
    func getOCRRecords(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) -> AnyPublisher<OCRRecordsData, NetworkError> {
        print("📋 获取OCR记录列表: page=\(page), limit=\(limit)")
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: startDate))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: endDate))
        }
        
        return networkManager.request(
            endpoint: .ocrRecords,
            method: .GET,
            queryItems: queryItems,
            responseType: APIResponse<OCRRecordsData>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 获取OCR记录失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "获取OCR记录失败")
            }
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "OCRAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取OCR记录成功: \(data.records.count)条记录")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR记录服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取单个OCR记录详情
    /// - Parameter recordId: OCR记录ID
    /// - Returns: OCR记录详情
    func getOCRRecord(recordId: String) -> AnyPublisher<OCRRecord, NetworkError> {
        print("🔍 获取OCR记录详情: recordId=\(recordId)")
        
        return networkManager.request(
            endpoint: .ocrRecords,
            pathComponent: recordId,
            method: .GET,
            responseType: APIResponse<OCRRecordDetailData>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 获取OCR记录详情失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "获取OCR记录详情失败")
            }
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "OCRAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取OCR记录详情成功: recordId=\(data.record.id)")
            return data.record
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR记录详情服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 删除OCR记录
    /// - Parameter recordId: OCR记录ID
    /// - Returns: 删除结果
    func deleteOCRRecord(recordId: String) -> AnyPublisher<Void, NetworkError> {
        print("🗑️ 删除OCR记录: recordId=\(recordId)")
        
        return networkManager.request(
            endpoint: .ocrRecords,
            pathComponent: recordId,
            method: .DELETE,
            responseType: APIResponse<String>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 删除OCR记录失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "删除OCR记录失败")
            }
            print("✅ 删除OCR记录成功: recordId=\(recordId)")
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR记录删除服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取OCR统计信息
    /// - Returns: OCR统计数据
    func getOCRStatistics() -> AnyPublisher<OCRStatisticsData, NetworkError> {
        print("📊 获取OCR统计信息")
        
        return networkManager.request(
            endpoint: .ocrStatistics,
            method: .GET,
            responseType: APIResponse<OCRStatisticsData>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 获取OCR统计信息失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "获取OCR统计信息失败")
            }
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "OCRAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取OCR统计信息成功")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 OCR统计服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取商户列表
    /// - Parameters:
    ///   - page: 页码
    ///   - limit: 每页数量
    ///   - category: 分类筛选
    ///   - search: 搜索关键词
    /// - Returns: 商户列表
    func getMerchants(
        page: Int = 1,
        limit: Int = 20,
        category: String? = nil,
        search: String? = nil
    ) -> AnyPublisher<OCRMerchantsData, NetworkError> {
        print("🏪 获取商户列表: page=\(page), limit=\(limit)")
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        return networkManager.request(
            endpoint: .ocrMerchants,
            method: .GET,
            queryItems: queryItems,
            responseType: APIResponse<OCRMerchantsData>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 获取商户列表失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "获取商户列表失败")
            }
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "OCRAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 获取商户列表成功: \(data.merchants.count)个商户")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 商户列表服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
    
    /// 智能匹配商户
    /// - Parameters:
    ///   - text: 要匹配的文本
    ///   - minConfidence: 最低置信度
    ///   - maxResults: 最大结果数
    /// - Returns: 匹配结果
    func matchMerchant(
        text: String,
        minConfidence: Double = 0.3,
        maxResults: Int = 10
    ) -> AnyPublisher<OCRMerchantMatchData, NetworkError> {
        print("🏪 智能匹配商户: text=\(text)")
        
        let request = OCRMerchantMatchRequest(
            text: text,
            minConfidence: minConfidence,
            maxResults: maxResults
        )
        
        return networkManager.request(
            endpoint: .ocrMerchantsMatch,
            method: .POST,
            body: request,
            responseType: APIResponse<OCRMerchantMatchData>.self
        )
        .tryMap { response in
            guard response.success else {
                print("❌ 商户匹配失败: \(response.message ?? "未知错误")")
                throw NetworkError.serverError(response.message ?? "商户匹配失败")
            }
            guard let data = response.data else {
                throw NetworkError.decodingError(NSError(domain: "OCRAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]))
            }
            print("✅ 商户匹配成功: 找到\(data.matches.count)个匹配")
            return data
        }
        .mapError { error in
            if let networkError = error as? NetworkError {
                if case .serverError(let message) = networkError,
                   message.contains("404") || message.contains("路由") || message.contains("不存在") {
                    print("🚫 商户匹配服务不可用")
                    return NetworkError.ocrServiceUnavailable
                }
                return networkError
            }
            return NetworkError.unknown(error)
        }
        .eraseToAnyPublisher()
    }
}

// 🚫 已将 APIResponse< String > 的便捷初始化移动到统一位置，避免重复声明 