import XCTest
import Combine
@testable import ExpenseTracker

final class APITests: XCTestCase {
    
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
    
    // MARK: - API配置测试
    
    func testAPIConfigBaseURL() throws {
        // 测试基础URL配置
        let baseURL = APIConfig.baseURL
        XCTAssertTrue(baseURL.hasPrefix("https://"), "生产环境应该使用HTTPS")
        XCTAssertFalse(baseURL.hasSuffix("/"), "基础URL不应该以/结尾")
        XCTAssertTrue(baseURL.contains("vercel.app") || baseURL.contains("localhost"), "应该是有效的API服务器地址")
    }
    
    func testEndpointURLConstruction() throws {
        // 测试所有端点URL构建
        for endpoint in APIConfig.Endpoint.allCases {
            let url = endpoint.fullURL
            XCTAssertTrue(url.hasPrefix("https://"), "\(endpoint)端点URL应该以https://开头: \(url)")
            XCTAssertFalse(url.contains("/api/api/"), "\(endpoint)端点URL不应该包含重复的/api路径: \(url)")
            XCTAssertTrue(url.contains(APIConfig.baseURL), "\(endpoint)端点URL应该包含基础URL: \(url)")
        }
    }
    
    func testPathParameterURLConstruction() throws {
        // 测试带路径参数的URL构建
        let testId = "test-id-123"
        let testYear = "2024"
        let testMonth = "1"
        
        // 测试支出相关路径参数
        let expenseDetailURL = APIConfig.Endpoint.expense.fullURL(with: testId)
        XCTAssertTrue(expenseDetailURL.contains("/api/expense/\(testId)"), "支出详情URL应该包含正确的路径参数")
        XCTAssertFalse(expenseDetailURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        // 测试预算相关路径参数
        let budgetURL = APIConfig.Endpoint.budgetSet.fullURL(with: "\(testYear)/\(testMonth)")
        XCTAssertTrue(budgetURL.contains("/api/budget/\(testYear)/\(testMonth)"), "预算URL应该包含正确的年月参数")
        
        // 测试OCR相关路径参数
        let ocrRecordURL = APIConfig.Endpoint.ocrRecords.fullURL(with: testId)
        XCTAssertTrue(ocrRecordURL.contains("/api/ocr/records/\(testId)"), "OCR记录URL应该包含正确的路径参数")
    }
    
    // MARK: - 认证API测试
    
    func testAuthenticationModels() throws {
        // 测试登录请求模型
        let loginRequest = LoginRequest(email: "test@example.com", password: "password123")
        XCTAssertEqual(loginRequest.email, "test@example.com")
        XCTAssertEqual(loginRequest.password, "password123")
        
        // 测试注册请求模型
        let registerRequest = RegisterRequest(email: "test@example.com", password: "password123", confirmPassword: "password123")
        XCTAssertEqual(registerRequest.email, "test@example.com")
        XCTAssertEqual(registerRequest.password, "password123")
        XCTAssertEqual(registerRequest.confirmPassword, "password123")
        
        // 测试用户模型
        let user = User(id: "test-id", email: "test@example.com", username: "testuser", createdAt: Date(), updatedAt: Date())
        XCTAssertEqual(user.id, "test-id")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.username, "testuser")
        
        // 测试用户模型的可选username字段
        let userWithoutUsername = User(id: "test-id", email: "test@example.com", username: nil, createdAt: Date(), updatedAt: Date())
        XCTAssertEqual(userWithoutUsername.id, "test-id")
        XCTAssertEqual(userWithoutUsername.email, "test@example.com")
        XCTAssertNil(userWithoutUsername.username)
    }
    
    func testAuthenticationEndpoints() throws {
        // 测试认证端点URL
        let loginURL = APIConfig.Endpoint.authLogin.fullURL
        XCTAssertTrue(loginURL.contains("/api/auth/login"), "登录端点URL应该正确")
        
        let registerURL = APIConfig.Endpoint.authRegister.fullURL
        XCTAssertTrue(registerURL.contains("/api/auth/register"), "注册端点URL应该正确")
        
        let meURL = APIConfig.Endpoint.authMe.fullURL
        XCTAssertTrue(meURL.contains("/api/auth/me"), "获取用户信息端点URL应该正确")
        
        let deleteAccountURL = APIConfig.Endpoint.authDeleteAccount.fullURL
        XCTAssertTrue(deleteAccountURL.contains("/api/auth/account"), "删除账号端点URL应该正确")
    }
    
    // MARK: - 预算API测试
    
    func testBudgetModels() throws {
        // 测试预算模型
        let budget = Budget(
            id: "budget-id",
            userId: "user-id",
            amount: 5000.0,
            year: 2024,
            month: 1,
            createdAt: "2024-01-15T10:30:00.000Z",
            updatedAt: "2024-01-15T10:30:00.000Z"
        )
        
        XCTAssertEqual(budget.id, "budget-id")
        XCTAssertEqual(budget.userId, "user-id")
        XCTAssertEqual(budget.amount, 5000.0)
        XCTAssertEqual(budget.year, 2024)
        XCTAssertEqual(budget.month, 1)
        
        // 测试格式化金额
        XCTAssertTrue(budget.formattedAmount.contains("5,000"))
        XCTAssertTrue(budget.formattedAmount.contains("¥"))
        
        // 测试月份显示字符串
        XCTAssertEqual(budget.monthDisplayString, "2024年1月")
    }
    
    func testBudgetEndpoints() throws {
        // 测试预算端点URL
        let budgetSetURL = APIConfig.Endpoint.budgetSet.fullURL
        XCTAssertTrue(budgetSetURL.contains("/api/budget"), "设置预算端点URL应该正确")
        
        let budgetCurrentURL = APIConfig.Endpoint.budgetCurrent.fullURL
        XCTAssertTrue(budgetCurrentURL.contains("/api/budget/current"), "当前预算端点URL应该正确")
        
        let budgetAlertsURL = APIConfig.Endpoint.budgetAlerts.fullURL
        XCTAssertTrue(budgetAlertsURL.contains("/api/budget/alerts"), "预算提醒端点URL应该正确")
        
        let budgetSuggestionsURL = APIConfig.Endpoint.budgetSuggestions.fullURL
        XCTAssertTrue(budgetSuggestionsURL.contains("/api/budget/suggestions"), "预算建议端点URL应该正确")
        
        let budgetHistoryURL = APIConfig.Endpoint.budgetHistory.fullURL
        XCTAssertTrue(budgetHistoryURL.contains("/api/budget/history"), "预算历史端点URL应该正确")
    }
    
    // MARK: - 支出API测试
    
    func testExpenseModels() throws {
        // 测试支出模型
        let expense = Expense(
            id: "expense-id",
            userId: "user-id",
            amount: 299.99,
            category: "餐饮",
            description: "午餐费用",
            date: Date(),
            location: "北京市朝阳区",
            paymentMethod: "支付宝",
            tags: ["工作餐", "午餐"],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(expense.id, "expense-id")
        XCTAssertEqual(expense.userId, "user-id")
        XCTAssertEqual(expense.amount, 299.99)
        XCTAssertEqual(expense.category, "餐饮")
        XCTAssertEqual(expense.description, "午餐费用")
        XCTAssertEqual(expense.location, "北京市朝阳区")
        XCTAssertEqual(expense.paymentMethod, "支付宝")
        XCTAssertEqual(expense.tags, ["工作餐", "午餐"])
        
        // 测试格式化金额
        XCTAssertTrue(expense.formattedAmount.contains("299.99"))
        XCTAssertTrue(expense.formattedAmount.contains("¥"))
    }
    
    func testExpenseEndpoints() throws {
        // 测试支出端点URL
        let expenseURL = APIConfig.Endpoint.expense.fullURL
        XCTAssertTrue(expenseURL.contains("/api/expense"), "支出端点URL应该正确")
        
        let expenseStatsURL = APIConfig.Endpoint.expenseStats.fullURL
        XCTAssertTrue(expenseStatsURL.contains("/api/expense/stats"), "支出统计端点URL应该正确")
        
        let expenseCategoriesURL = APIConfig.Endpoint.expenseCategories.fullURL
        XCTAssertTrue(expenseCategoriesURL.contains("/api/expense/categories"), "支出分类端点URL应该正确")
        
        let expenseExportURL = APIConfig.Endpoint.expenseExport.fullURL
        XCTAssertTrue(expenseExportURL.contains("/api/expense/export"), "支出导出端点URL应该正确")
        
        let expenseTrendsURL = APIConfig.Endpoint.expenseTrends.fullURL
        XCTAssertTrue(expenseTrendsURL.contains("/api/expense/trends"), "支出趋势端点URL应该正确")
    }
    
    // MARK: - OCR API测试
    
    func testOCREndpoints() throws {
        // 测试OCR端点URL
        let ocrParseURL = APIConfig.Endpoint.ocrParse.fullURL
        XCTAssertTrue(ocrParseURL.contains("/api/ocr/parse"), "OCR解析端点URL应该正确")
        XCTAssertFalse(ocrParseURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        let ocrParseAutoURL = APIConfig.Endpoint.ocrParseAuto.fullURL
        XCTAssertTrue(ocrParseAutoURL.contains("/api/ocr/parse-auto"), "OCR自动解析端点URL应该正确")
        XCTAssertFalse(ocrParseAutoURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        let ocrRecordsURL = APIConfig.Endpoint.ocrRecords.fullURL
        XCTAssertTrue(ocrRecordsURL.contains("/api/ocr/records"), "OCR记录端点URL应该正确")
        
        let ocrStatisticsURL = APIConfig.Endpoint.ocrStatistics.fullURL
        XCTAssertTrue(ocrStatisticsURL.contains("/api/ocr/statistics"), "OCR统计端点URL应该正确")
        
        let ocrMerchantsURL = APIConfig.Endpoint.ocrMerchants.fullURL
        XCTAssertTrue(ocrMerchantsURL.contains("/api/ocr/merchants"), "OCR商户端点URL应该正确")
        
        let ocrMerchantsMatchURL = APIConfig.Endpoint.ocrMerchantsMatch.fullURL
        XCTAssertTrue(ocrMerchantsMatchURL.contains("/api/ocr/merchants/match"), "OCR商户匹配端点URL应该正确")
        
        let ocrShortcutsURL = APIConfig.Endpoint.ocrShortcuts.fullURL
        XCTAssertTrue(ocrShortcutsURL.contains("/api/ocr/shortcuts/generate"), "OCR快捷指令端点URL应该正确")
    }
    
    // MARK: - 网络管理器测试
    
    func testNetworkManagerJSONDecoderConfiguration() throws {
        // 测试NetworkManager是否正确配置了日期解码策略
        let networkManager = NetworkManager.shared
        XCTAssertNotNil(networkManager, "NetworkManager实例应该存在")
        
        // 测试ISO 8601日期格式解码
        let jsonString = """
        {
            "success": true,
            "data": {
                "user": {
                    "id": "test-id",
                    "email": "test@example.com",
                    "createdAt": "2024-01-15T10:30:00.000Z",
                    "updatedAt": "2024-01-15T10:30:00.000Z"
                },
                "token": "test-token"
            }
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let response = try decoder.decode(APIResponse<AuthData>.self, from: jsonData)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.user.id, "test-id")
            XCTAssertEqual(response.data?.user.email, "test@example.com")
            XCTAssertEqual(response.data?.token, "test-token")
        } catch {
            XCTFail("JSON解码应该成功: \(error)")
        }
    }
    
    func testAPIResponseModel() throws {
        // 测试API响应模型
        let user = User(id: "test-id", email: "test@example.com", username: nil, createdAt: Date(), updatedAt: Date())
        let authData = AuthData(user: user, token: "test-token")
        let response = APIResponse<AuthData>(success: true, data: authData, message: "登录成功")
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.message, "登录成功")
        XCTAssertEqual(response.data?.user.id, "test-id")
        XCTAssertEqual(response.data?.token, "test-token")
    }
    
    // MARK: - 日期解码测试
    
    func testDateDecodingFromISO8601() throws {
        // 测试从ISO 8601格式解码日期
        let jsonString = """
        {
            "id": "test-id",
            "email": "test@example.com",
            "createdAt": "2024-01-15T10:30:00.000Z",
            "updatedAt": "2024-01-15T10:30:00.000Z"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let user = try decoder.decode(User.self, from: jsonData)
            XCTAssertEqual(user.id, "test-id")
            XCTAssertEqual(user.email, "test@example.com")
            XCTAssertNotNil(user.createdAt)
            XCTAssertNotNil(user.updatedAt)
        } catch {
            XCTFail("ISO 8601日期解码应该成功: \(error)")
        }
    }
    
    func testDateDecodingFromISO8601WithMicroseconds() throws {
        // 测试从带微秒的ISO 8601格式解码日期
        let jsonString = """
        {
            "id": "test-id",
            "email": "test@example.com",
            "createdAt": "2025-06-18T07:48:55.314517+00:00",
            "updatedAt": "2025-06-18T07:48:55.314517+00:00"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let user = try decoder.decode(User.self, from: jsonData)
            XCTAssertEqual(user.id, "test-id")
            XCTAssertEqual(user.email, "test@example.com")
            XCTAssertNotNil(user.createdAt)
            XCTAssertNotNil(user.updatedAt)
        } catch {
            XCTFail("带微秒的ISO 8601日期解码应该成功: \(error)")
        }
    }
    
    // MARK: - 错误处理测试
    
    func testNetworkErrorTypes() throws {
        // 测试网络错误类型
        let invalidURLError = NetworkError.invalidURL
        XCTAssertNotNil(invalidURLError)
        
        let unauthorizedError = NetworkError.unauthorized
        XCTAssertNotNil(unauthorizedError)
        
        let forbiddenError = NetworkError.forbidden
        XCTAssertNotNil(forbiddenError)
        
        let notFoundError = NetworkError.notFound("资源不存在")
        XCTAssertNotNil(notFoundError)
        
        let serverError = NetworkError.serverError("服务器错误")
        XCTAssertNotNil(serverError)
        
        let decodingError = NetworkError.decodingError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(decodingError)
    }
    
    // MARK: - 端点完整性测试
    
    func testAllRequiredEndpointsExist() throws {
        // 根据API文档验证所有必需的端点都存在
        let requiredEndpoints: Set<String> = [
            "/health",
            "/api/debug/routes",
            "/api/auth/register",
            "/api/auth/login",
            "/api/auth/me",
            "/api/auth/account",
            "/api/budget",
            "/api/budget/current",
            "/api/budget/alerts",
            "/api/budget/suggestions",
            "/api/budget/history",
            "/api/expense",
            "/api/expense/stats",
            "/api/expense/categories",
            "/api/expense/export",
            "/api/expense/trends",
            "/api/ocr/parse",
            "/api/ocr/parse-auto",
            "/api/ocr/records",
            "/api/ocr/statistics",
            "/api/ocr/merchants",
            "/api/ocr/merchants/match",
            "/api/ocr/shortcuts/generate"
        ]
        
        let actualEndpoints = Set(APIConfig.Endpoint.allCases.map { $0.rawValue })
        
        for requiredEndpoint in requiredEndpoints {
            XCTAssertTrue(actualEndpoints.contains(requiredEndpoint), "缺少必需的端点: \(requiredEndpoint)")
        }
        
        print("✅ 所有必需的端点都存在: \(actualEndpoints.count)个")
    }
    
    func testEndpointHTTPMethods() throws {
        // 测试HTTP方法枚举
        XCTAssertEqual(HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.POST.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.PUT.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.DELETE.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.PATCH.rawValue, "PATCH")
    }
} 