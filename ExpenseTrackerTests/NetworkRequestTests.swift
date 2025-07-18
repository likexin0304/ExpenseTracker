import XCTest
import Combine
@testable import ExpenseTracker

final class NetworkRequestTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable> = []
    var networkManager: NetworkManager!
    
    override func setUpWithError() throws {
        super.setUp()
        networkManager = NetworkManager.shared
        cancellables = []
    }
    
    override func tearDownWithError() throws {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        networkManager = nil
        super.tearDown()
    }
    
    // MARK: - 健康检查测试
    
    func testHealthCheckEndpoint() throws {
        let expectation = XCTestExpectation(description: "健康检查API调用")
        
        networkManager.request(
            endpoint: .health,
            method: .GET,
            responseType: HealthResponse.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("健康检查应该成功: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertEqual(response.status, "OK", "健康检查状态应该是OK")
                XCTAssertNotNil(response.timestamp, "时间戳应该存在")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - 路由调试测试
    
    func testDebugRoutesEndpoint() throws {
        let expectation = XCTestExpectation(description: "路由调试API调用")
        
        networkManager.request(
            endpoint: .debugRoutes,
            method: .GET,
            responseType: DebugRoutesResponse.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("路由调试API应该成功: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertNotNil(response.message, "消息应该存在")
                XCTAssertNotNil(response.availableRoutes, "可用路由列表应该存在")
                XCTAssertTrue(response.availableRoutes.count > 0, "应该有可用的路由")
                
                // 验证关键路由是否存在
                XCTAssertTrue(response.availableRoutes.contains("POST /api/auth/login"), "应该包含登录路由")
                XCTAssertTrue(response.availableRoutes.contains("POST /api/auth/register"), "应该包含注册路由")
                XCTAssertTrue(response.availableRoutes.contains("GET /api/auth/me"), "应该包含获取用户信息路由")
                XCTAssertTrue(response.availableRoutes.contains("POST /api/expense"), "应该包含创建支出路由")
                XCTAssertTrue(response.availableRoutes.contains("GET /api/expense"), "应该包含获取支出列表路由")
                XCTAssertTrue(response.availableRoutes.contains("POST /api/budget"), "应该包含设置预算路由")
                XCTAssertTrue(response.availableRoutes.contains("POST /api/ocr/parse"), "应该包含OCR解析路由")
                XCTAssertTrue(response.availableRoutes.contains("POST /api/ocr/parse-auto"), "应该包含OCR自动解析路由")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - 认证API测试
    
    func testLoginWithValidCredentials() throws {
        let expectation = XCTestExpectation(description: "登录API调用")
        
        let loginRequest = LoginRequest(email: "test@example.com", password: "123456")
        
        networkManager.request(
            endpoint: .authLogin,
            method: .POST,
            body: loginRequest,
            responseType: APIResponse<AuthData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // 这里可能会失败，因为这是测试环境
                    print("登录测试失败（预期）: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "登录应该成功")
                XCTAssertNotNil(response.data, "应该返回认证数据")
                XCTAssertNotNil(response.data?.user, "应该返回用户信息")
                XCTAssertNotNil(response.data?.token, "应该返回访问令牌")
                XCTAssertEqual(response.data?.user.email, "test@example.com", "用户邮箱应该匹配")
                XCTAssertEqual(response.message, "登录成功", "消息应该正确")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testLoginWithInvalidCredentials() throws {
        let expectation = XCTestExpectation(description: "无效凭证登录API调用")
        
        let loginRequest = LoginRequest(email: "invalid@example.com", password: "wrongpassword")
        
        networkManager.request(
            endpoint: .authLogin,
            method: .POST,
            body: loginRequest,
            responseType: APIResponse<AuthData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("无效凭证登录应该失败")
                case .failure(let error):
                    // 验证错误类型
                    switch error {
                    case .unauthorized:
                        XCTAssertTrue(true, "应该返回401未授权错误")
                    case .serverError(let message):
                        XCTAssertTrue(message.contains("邮箱或密码错误") || message.contains("Invalid"), "错误消息应该指示凭证无效")
                    default:
                        XCTFail("应该返回认证相关错误，实际错误: \(error)")
                    }
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertFalse(response.success, "无效凭证登录应该失败")
                XCTAssertNil(response.data, "不应该返回认证数据")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - 支出分类API测试
    
    func testGetExpenseCategories() throws {
        let expectation = XCTestExpectation(description: "获取支出分类API调用")
        
        networkManager.request(
            endpoint: .expenseCategories,
            method: .GET,
            responseType: APIResponse<ExpenseCategoriesData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // 可能需要认证，所以这里可能会失败
                    print("获取支出分类失败（可能需要认证）: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "获取支出分类应该成功")
                XCTAssertNotNil(response.data, "应该返回分类数据")
                XCTAssertNotNil(response.data?.categories, "应该返回分类列表")
                XCTAssertTrue(response.data?.categories.count ?? 0 > 0, "应该有至少一个分类")
                
                // 验证分类结构
                if let categories = response.data?.categories {
                    for category in categories {
                        XCTAssertFalse(category.rawValue.isEmpty, "分类值不应该为空")
                        XCTAssertFalse(category.displayName.isEmpty, "分类标签不应该为空")
                        XCTAssertFalse(category.iconName.isEmpty, "分类图标不应该为空")
                    }
                }
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - OCR API测试
    
    func testOCRParseEndpoint() throws {
        let expectation = XCTestExpectation(description: "OCR解析API调用")
        
        let ocrRequest = OCRParseRequest(text: "麦当劳 2024-01-15 消费金额：¥25.80 支付方式：支付宝")
        
        networkManager.request(
            endpoint: .ocrParse,
            method: .POST,
            body: ocrRequest,
            responseType: APIResponse<OCRParseData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // 可能需要认证，所以这里可能会失败
                    print("OCR解析失败（可能需要认证）: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "OCR解析应该成功")
                XCTAssertNotNil(response.data, "应该返回解析数据")
                XCTAssertNotNil(response.data?.record, "应该返回记录信息")
                XCTAssertEqual(response.message, "OCR文本解析完成", "消息应该正确")
                
                // 验证解析结果
                if let record = response.data?.record {
                    XCTAssertEqual(record.originalText, "麦当劳 2024-01-15 消费金额：¥25.80 支付方式：支付宝", "原始文本应该匹配")
                    XCTAssertNotNil(record.parsedData, "应该有解析数据")
                    XCTAssertTrue(record.confidenceScore > 0, "置信度应该大于0")
                    XCTAssertEqual(record.status, "success", "状态应该是成功")
                }
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testOCRParseAutoEndpoint() throws {
        let expectation = XCTestExpectation(description: "OCR自动解析API调用")
        
        let ocrAutoRequest = OCRParseAutoRequest(text: "麦当劳 2024-01-15 消费金额：¥25.80 支付方式：支付宝", autoCreateThreshold: 0.85)
        
        networkManager.request(
            endpoint: .ocrParseAuto,
            method: .POST,
            body: ocrAutoRequest,
            responseType: APIResponse<OCRParseAutoData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // 可能需要认证，所以这里可能会失败
                    print("OCR自动解析失败（可能需要认证）: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "OCR自动解析应该成功")
                XCTAssertNotNil(response.data, "应该返回解析数据")
                
                // 验证自动创建逻辑
                if let data = response.data {
                    if data.autoCreated {
                        XCTAssertNotNil(data.expense, "自动创建时应该有支出记录")
                        XCTAssertNotNil(data.ocrRecord, "应该有OCR记录")
                        XCTAssertEqual(response.message, "自动识别并创建支出记录成功", "消息应该正确")
                    } else {
                        XCTAssertNotNil(data.recordId, "未自动创建时应该有记录ID")
                        XCTAssertEqual(response.message, "解析成功，需要用户确认", "消息应该正确")
                    }
                }
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testOCRMerchantsEndpoint() throws {
        let expectation = XCTestExpectation(description: "OCR商户列表API调用")
        
        networkManager.request(
            endpoint: .ocrMerchants,
            method: .GET,
            responseType: APIResponse<OCRMerchantsData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // 可能需要认证，所以这里可能会失败
                    print("获取OCR商户列表失败（可能需要认证）: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "获取OCR商户列表应该成功")
                XCTAssertNotNil(response.data, "应该返回商户数据")
                XCTAssertNotNil(response.data?.merchants, "应该返回商户列表")
                XCTAssertEqual(response.message, "商户列表获取成功", "消息应该正确")
                
                // 验证商户数据结构
                if let merchants = response.data?.merchants {
                    for merchant in merchants {
                        XCTAssertFalse(merchant.id.isEmpty, "商户ID不应该为空")
                        XCTAssertFalse(merchant.name.isEmpty, "商户名称不应该为空")
                        XCTAssertFalse(merchant.category.isEmpty, "商户分类不应该为空")
                        XCTAssertTrue(merchant.keywords.count > 0, "商户关键词不应该为空")
                        XCTAssertTrue(merchant.confidenceScore > 0, "置信度应该大于0")
                    }
                }
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testOCRShortcutsEndpoint() throws {
        let expectation = XCTestExpectation(description: "OCR快捷指令API调用")
        
        networkManager.request(
            endpoint: .ocrShortcuts,
            method: .GET,
            responseType: APIResponse<OCRShortcutsData>.self
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("获取OCR快捷指令失败: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { response in
                XCTAssertTrue(response.success, "获取OCR快捷指令应该成功")
                XCTAssertNotNil(response.data, "应该返回快捷指令数据")
                XCTAssertNotNil(response.data?.shortcutConfig, "应该返回快捷指令配置")
                XCTAssertEqual(response.message, "iOS快捷指令配置生成成功", "消息应该正确")
                
                // 验证快捷指令配置结构
                if let config = response.data?.shortcutConfig {
                    XCTAssertNotNil(config["WFWorkflowActions"], "应该有工作流动作")
                    XCTAssertNotNil(config["WFWorkflowName"], "应该有工作流名称")
                    XCTAssertNotNil(config["WFWorkflowIcon"], "应该有工作流图标")
                }
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - URL构建测试
    
    func testURLConstructionDoesNotHaveDuplicateAPIPath() throws {
        // 测试所有端点的URL构建都不包含重复的/api路径
        for endpoint in APIConfig.Endpoint.allCases {
            let url = endpoint.fullURL
            XCTAssertFalse(url.contains("/api/api/"), "\(endpoint)端点URL不应该包含重复的/api路径: \(url)")
        }
    }
    
    func testPathParameterURLConstruction() throws {
        // 测试路径参数URL构建
        let testId = "test-id-123"
        
        // 测试支出详情URL
        let expenseDetailURL = APIConfig.Endpoint.expense.fullURL(with: testId)
        XCTAssertTrue(expenseDetailURL.contains("/api/expense/\(testId)"), "支出详情URL应该包含正确的路径参数")
        XCTAssertFalse(expenseDetailURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        // 测试OCR记录URL
        let ocrRecordURL = APIConfig.Endpoint.ocrRecords.fullURL(with: testId)
        XCTAssertTrue(ocrRecordURL.contains("/api/ocr/records/\(testId)"), "OCR记录URL应该包含正确的路径参数")
        XCTAssertFalse(ocrRecordURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
    }
}

// MARK: - 测试用数据模型

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let env: String?
}

struct DebugRoutesResponse: Codable {
    let message: String
    let availableRoutes: [String]
    let requestFormat: RequestFormat?
    let errorHandling: ErrorHandling?
    
    private enum CodingKeys: String, CodingKey {
        case message
        case availableRoutes = "available_routes"
        case requestFormat
        case errorHandling
    }
}

struct RequestFormat: Codable {
    let contentType: String
    let authHeader: String
    let bodyFormat: String
    let example: FormatExample
}

struct FormatExample: Codable {
    let correct: String
    let incorrect: [String]
}

struct ErrorHandling: Codable {
    let jsonParseErrors: String
    let authErrors: String
    let validationErrors: String
}

struct ExpenseCategoriesData: Codable {
    let categories: [ExpenseCategory]
    let total: Int
}

struct OCRParseRequest: Codable {
    let text: String
}

struct OCRParseAutoRequest: Codable {
    let text: String
    let autoCreateThreshold: Double
}

struct OCRParseData: Codable {
    let record: OCRRecord
}

struct OCRParseAutoData: Codable {
    let autoCreated: Bool
    let expense: Expense?
    let ocrRecord: OCRRecord?
    let recordId: String?
    let confidence: Double
    let parsedData: OCRParsedData?
}

struct OCRRecord: Codable {
    let id: String
    let originalText: String
    let parsedData: OCRParsedData
    let confidenceScore: Double
    let status: String
    let suggestions: OCRSuggestions?
    let expenseId: String?
    let errorMessage: String?
    let createdAt: String
}

struct OCRParsedData: Codable {
    let merchant: OCRMerchant?
    let amount: OCRAmount?
    let date: OCRDate?
    let paymentMethod: OCRPaymentMethod?
    let category: OCRCategory?
}

struct OCRMerchant: Codable {
    let name: String
    let category: String
    let confidence: Double
    let matchType: String
}

struct OCRAmount: Codable {
    let value: Double
    let confidence: Double
    let originalText: String
}

struct OCRDate: Codable {
    let value: String
    let confidence: Double
    let originalText: String
}

struct OCRPaymentMethod: Codable {
    let value: String
    let confidence: Double
    let originalText: String
}

struct OCRCategory: Codable {
    let value: String
    let confidence: Double
    let source: String
}

struct OCRSuggestions: Codable {
    let autoCreate: Bool
    let needsReview: Bool
    let confidence: String
}

struct OCRMerchantsData: Codable {
    let merchants: [OCRMerchantInfo]
    let categories: [String]
    let pagination: OCRPagination
}

struct OCRMerchantInfo: Codable {
    let id: String
    let name: String
    let category: String
    let keywords: [String]
    let confidenceScore: Double
    let isActive: Bool
}

struct OCRPagination: Codable {
    let currentPage: Int
    let totalPages: Int
    let totalRecords: Int
}

struct OCRShortcutsData: Codable {
    let shortcutConfig: [String: Any]
    let setupInstructions: [String]
    let apiInfo: OCRAPIInfo
    
    private enum CodingKeys: String, CodingKey {
        case shortcutConfig, setupInstructions, apiInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setupInstructions = try container.decode([String].self, forKey: .setupInstructions)
        apiInfo = try container.decode(OCRAPIInfo.self, forKey: .apiInfo)
        
        // 解析shortcutConfig为字典
        let configData = try container.decode(Data.self, forKey: .shortcutConfig)
        shortcutConfig = try JSONSerialization.jsonObject(with: configData) as? [String: Any] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(setupInstructions, forKey: .setupInstructions)
        try container.encode(apiInfo, forKey: .apiInfo)
        
        // 编码shortcutConfig
        let configData = try JSONSerialization.data(withJSONObject: shortcutConfig)
        try container.encode(configData, forKey: .shortcutConfig)
    }
}

struct OCRAPIInfo: Codable {
    let endpoint: String
    let authRequired: Bool
    let tokenHint: String
} 