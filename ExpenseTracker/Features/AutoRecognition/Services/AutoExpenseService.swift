import Foundation
import Combine

// MARK: - Auto Expense Result
enum AutoExpenseResult {
    case success(AutoExpenseData)
    case failure(String)
}

// 🚫 移除重复的 ExpenseCorrections 定义（已在 Models 层统一实现）

// MARK: - Auto Expense Service
class AutoExpenseService {
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Auto Expense Processing
    
    /// 处理自动记账：从OCR文本解析支出信息
    /// - Parameter ocrText: OCR识别的文本
    /// - Returns: 解析结果或错误信息
    func processAutoExpense(ocrText: String) -> AnyPublisher<AutoExpenseResult, Never> {
        // 构建请求数据
        let requestData = AutoExpenseRequestDTO(
            text: ocrText,
            autoCreateThreshold: 0.8
        )
        
        return networkManager.request(
            endpoint: .ocrParseAuto,
            method: .POST,
            body: requestData,
            responseType: APIResponse<AutoExpenseData>.self
        )
        .map { (response: APIResponse<AutoExpenseData>) -> AutoExpenseResult in
            if response.success {
                if let data = response.data {
                    return .success(data)
                } else {
                    return .failure("解析响应数据失败：数据为空")
                }
            } else {
                return .failure(response.message ?? "解析响应数据失败")
            }
        }
        .catch { (error: Error) -> AnyPublisher<AutoExpenseResult, Never> in
            Just(.failure(error.localizedDescription))
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// 确认并创建支出记录
    /// - Parameters:
    ///   - recordId: OCR记录ID
    ///   - corrections: 用户修正的数据
    /// - Returns: 创建的支出记录或错误信息
    func confirmAndCreateExpense(recordId: String, corrections: ExpenseCorrections) -> AnyPublisher<Result<Expense, NetworkError>, Never> {
        // 使用现有的CreateExpenseRequest结构
        let requestData = CreateExpenseRequest(
            amount: corrections.amount ?? 0.0,
            category: corrections.category?.rawValue ?? ExpenseCategory.other.rawValue,
            description: corrections.description ?? "",
            date: corrections.date,
            location: corrections.location,
            paymentMethod: corrections.paymentMethod?.rawValue ?? PaymentMethod.other.rawValue,
            tags: corrections.tags ?? []
        )
        
        return networkManager.request(
            endpoint: .expense,
            method: .POST,
            body: requestData,
            responseType: APIResponse<Expense>.self
        )
        .map { (response: APIResponse<Expense>) -> Result<Expense, NetworkError> in
            if response.success {
                if let data = response.data {
                    return .success(data)
                } else {
                    return .failure(NetworkError.serverError("创建支出记录失败：数据为空"))
                }
            } else {
                return .failure(NetworkError.serverError(response.message ?? "创建支出记录失败"))
            }
        }
        .catch { (error: Error) -> AnyPublisher<Result<Expense, NetworkError>, Never> in
            let networkError = error as? NetworkError ?? NetworkError.unknown(error)
            return Just(.failure(networkError))
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取支出类别列表
    /// - Returns: 支出类别列表或错误信息
    func getExpenseCategories() -> AnyPublisher<Result<[String], NetworkError>, Never> {
        return networkManager.request(
            endpoint: .expenseCategories,
            method: .GET,
            responseType: APIResponse<AutoExpenseCategoriesResponse>.self
        )
        .map { (response: APIResponse<AutoExpenseCategoriesResponse>) -> Result<[String], NetworkError> in
            if response.success {
                if let data = response.data {
                    // 将ExpenseCategory转换为String数组
                    let categoryStrings = data.categories.map { $0.displayName }
                    return .success(categoryStrings)
                } else {
                    return .failure(NetworkError.serverError("获取类别列表失败：数据为空"))
                }
            } else {
                return .failure(NetworkError.serverError(response.message ?? "获取类别列表失败"))
            }
        }
        .catch { (error: Error) -> AnyPublisher<Result<[String], NetworkError>, Never> in
            let networkError = error as? NetworkError ?? NetworkError.unknown(error)
            return Just(.failure(networkError))
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - DTO Models

/// 用于网络请求的自动支出请求DTO
struct AutoExpenseRequestDTO: Codable {
    let text: String
    let autoCreateThreshold: Double
} 