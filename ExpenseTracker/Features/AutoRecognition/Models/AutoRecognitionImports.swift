import Foundation
import SwiftUI
import Combine

// MARK: - OCR Data Structure
public struct OCRData {
    public let id: UUID
    public let text: String
    public let confidence: Double
    public let textBlocks: [TextBlock]
    public let timestamp: Date
    
    public init(id: UUID = UUID(), text: String, confidence: Double, textBlocks: [TextBlock] = [], timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.textBlocks = textBlocks
        self.timestamp = timestamp
    }
}

public struct TextBlock {
    public let text: String
    public let confidence: Double
    public let boundingBox: CGRect
    
    public init(text: String, confidence: Double, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
    
    // Computed properties for compatibility with DataParsingService
    public var isPotentialAmount: Bool {
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let amountPatterns = [
            "^[¥$€]?[0-9,]+\\.?[0-9]*$",
            "^[0-9,]+\\.[0-9]{2}元?$",
            "^[0-9,]+元$"
        ]
        
        for pattern in amountPatterns {
            if normalizedText.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return normalizedText.contains("¥") || normalizedText.contains("$") || normalizedText.contains("€")
    }
    
    public var isPotentialMerchant: Bool {
        let merchantKeywords = ["店", "餐厅", "公司", "有限", "超市", "商场", "中心"]
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return merchantKeywords.contains(where: { normalizedText.contains($0) }) && text.count > 3
    }
}

// MARK: - Processing State
public enum ProcessingState: Equatable {
    case idle
    case waitingForConfirmation
    case capturingScreen
    case recognizing
    case parsing
    case success(RecognitionResult)
    case failed(AutoRecognitionError)
    case cancelled
    
    public var displayText: String {
        switch self {
        case .idle:
            return "待机"
        case .waitingForConfirmation:
            return "等待确认"
        case .capturingScreen:
            return "正在截取屏幕"
        case .recognizing:
            return "正在识别"
        case .parsing:
            return "正在解析"
        case .success:
            return "识别成功"
        case .failed:
            return "识别失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    public static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.waitingForConfirmation, .waitingForConfirmation),
             (.capturingScreen, .capturingScreen), (.recognizing, .recognizing),
             (.parsing, .parsing), (.cancelled, .cancelled):
            return true
        case (.success(let lhsResult), .success(let rhsResult)):
            return lhsResult.id == rhsResult.id
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Recognition Result
public struct RecognitionResult {
    public let id: UUID
    public let ocrData: OCRData
    public let amounts: [Double]
    public let merchants: [String]
    public let suggestedCategory: String
    public let categoryConfidence: Double
    public let timestamp: Date
    public let isValid: Bool
    
    // 编辑状态属性
    public var selectedAmount: Double?
    public var editedDescription: String?
    public var editedTransactionTime: Date?
    
    public init(
        id: UUID = UUID(),
        ocrData: OCRData,
        amounts: [Double] = [],
        merchants: [String] = [],
        suggestedCategory: String = "other",
        categoryConfidence: Double = 0.0,
        timestamp: Date = Date(),
        isValid: Bool = false
    ) {
        self.id = id
        self.ocrData = ocrData
        self.amounts = amounts
        self.merchants = merchants
        self.suggestedCategory = suggestedCategory
        self.categoryConfidence = categoryConfidence
        self.timestamp = timestamp
        self.isValid = isValid
        self.selectedAmount = nil
        self.editedDescription = nil
        self.editedTransactionTime = nil
    }
}



// MARK: - Auto Recognition State
public struct AutoRecognitionState {
    public var isEnabled: Bool
    public var processingState: ProcessingState
    public var currentResult: RecognitionResult?
    public var recentResults: [RecognitionResult]
    public var isTestMode: Bool
    public var errorMessage: String?
    public var showTutorial: Bool
    public var isProcessing: Bool
    public var progress: Double
    public var progressMessage: String
    public var backTapLogs: [String]
    public var recognitionResult: RecognitionResult?
    
    public init(
        isEnabled: Bool = false,
        processingState: ProcessingState = .idle,
        currentResult: RecognitionResult? = nil,
        recentResults: [RecognitionResult] = [],
        isTestMode: Bool = false,
        errorMessage: String? = nil,
        showTutorial: Bool = false,
        isProcessing: Bool = false,
        progress: Double = 0.0,
        progressMessage: String = "",
        backTapLogs: [String] = [],
        recognitionResult: RecognitionResult? = nil
    ) {
        self.isEnabled = isEnabled
        self.processingState = processingState
        self.currentResult = currentResult
        self.recentResults = recentResults
        self.isTestMode = isTestMode
        self.errorMessage = errorMessage
        self.showTutorial = showTutorial
        self.isProcessing = isProcessing
        self.progress = progress
        self.progressMessage = progressMessage
        self.backTapLogs = backTapLogs
        self.recognitionResult = recognitionResult
    }
}

// MARK: - Auto Recognition Actions
public enum AutoRecognitionAction {
    case toggleEnabled
    case toggleTestMode
    case manualTrigger
    case updateProcessingState(ProcessingState)
    case updateProgress(Double, String)
    case cancelRecognition
    case retryRecognition
    case confirmResult
    case showTutorial
    case completeTutorial
    case clearLogs
    case setEnabled(Bool)
    case setProcessingState(ProcessingState)
    case setCurrentResult(RecognitionResult?)
    case addResult(RecognitionResult)
    case setTestMode(Bool)
    case setError(String?)
    case setShowTutorial(Bool)
    case setIsProcessing(Bool)
    case clearResults
    case reset
}

// MARK: - Auto Recognition Error
public enum AutoRecognitionError: Error, LocalizedError {
    case captureFailure(String)
    case ocrFailure(String)
    case ocrFailed(String)  // Alias for compatibility
    case recognitionFailure(String)  // New case for recognition failures
    case parsingFailure(String)
    case networkError(String)
    case invalidImage
    case permissionDenied
    case serviceUnavailable
    case unknownError(String)
    case noValidAmountFound  // New case for DataParsingService
    
    public var errorDescription: String? {
        switch self {
        case .captureFailure(let message):
            return "截图失败: \(message)"
        case .ocrFailure(let message), .ocrFailed(let message):
            return "OCR识别失败: \(message)"
        case .recognitionFailure(let message):
            return "识别失败: \(message)"
        case .parsingFailure(let message):
            return "解析失败: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .invalidImage:
            return "无效的图像"
        case .permissionDenied:
            return "权限被拒绝"
        case .serviceUnavailable:
            return "智能识别功能暂时不可用，请稍后再试或使用手动添加方式"
        case .unknownError(let message):
            return "未知错误: \(message)"
        case .noValidAmountFound:
            return "未找到有效的金额"
        }
    }
}

// MARK: - Auto Recognition Reducer
public struct AutoRecognitionReducer {
    public static func reduce(state: inout AutoRecognitionState, action: AutoRecognitionAction) {
        switch action {
        case .toggleEnabled:
            state.isEnabled.toggle()
            
        case .toggleTestMode:
            state.isTestMode.toggle()
            
        case .manualTrigger:
            state.processingState = .capturingScreen
            state.isProcessing = true
            
        case .updateProcessingState(let processingState):
            state.processingState = processingState
            state.isProcessing = processingState != .idle && processingState != .cancelled
            
        case .updateProgress(let progress, let message):
            // Progress updates could be stored in state if needed
            break
            
        case .cancelRecognition:
            state.processingState = .cancelled
            state.isProcessing = false
            
        case .retryRecognition:
            state.processingState = .capturingScreen
            state.isProcessing = true
            state.errorMessage = nil
            
        case .confirmResult:
            if case .success(let result) = state.processingState {
                state.currentResult = result
                state.recentResults.insert(result, at: 0)
                if state.recentResults.count > 50 {
                    state.recentResults = Array(state.recentResults.prefix(50))
                }
            }
            state.processingState = .idle
            state.isProcessing = false
            
        case .showTutorial:
            state.showTutorial = true
            
        case .completeTutorial:
            state.showTutorial = false
            
        case .clearLogs:
            state.recentResults.removeAll()
            
        case .setEnabled(let enabled):
            state.isEnabled = enabled
            
        case .setProcessingState(let processingState):
            state.processingState = processingState
            state.isProcessing = processingState != .idle && processingState != .cancelled
            
        case .setCurrentResult(let result):
            state.currentResult = result
            
        case .addResult(let result):
            state.recentResults.insert(result, at: 0)
            if state.recentResults.count > 50 {
                state.recentResults = Array(state.recentResults.prefix(50))
            }
            
        case .setTestMode(let testMode):
            state.isTestMode = testMode
            
        case .setError(let error):
            state.errorMessage = error
            
        case .setShowTutorial(let show):
            state.showTutorial = show
            
        case .setIsProcessing(let processing):
            state.isProcessing = processing
            
        case .clearResults:
            state.recentResults.removeAll()
            state.currentResult = nil
            
        case .reset:
            state = AutoRecognitionState()
        }
    }
}

// MARK: - Additional OCR Types
public enum OCRTextType {
    case amount
    case merchant
    case date
    case category
    case other
    case currency  // For currency symbols
    case time      // For time information
    case header    // For header/title text
    case general   // For general text
}

public struct OCRTextBlock {
    public let text: String
    public let confidence: Double
    public let boundingBox: CGRect
    public let textType: OCRTextType
    
    public init(text: String, confidence: Double, boundingBox: CGRect, textType: OCRTextType = .other) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.textType = textType
    }
    
    // Computed properties for compatibility with OCRService
    public var isPotentialAmount: Bool {
        return textType == .amount || textType == .currency
    }
    
    public var isPotentialMerchant: Bool {
        return textType == .merchant || textType == .header
    }
}

// MARK: - Category Suggestion
public struct CategorySuggestion {
    public let category: String
    public let confidence: Double
    public let reasoning: String
    
    public init(category: String, confidence: Double, reasoning: String = "") {
        self.category = category
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

// MARK: - Permission Status
public enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
}

// MARK: - Recognition Result Extensions
extension RecognitionResult {
    public static func createTestData() -> RecognitionResult {
        let testOCRData = OCRData(
            text: "星巴克咖啡 ¥35.00 2024-01-17",
            confidence: 0.95,
            textBlocks: [
                TextBlock(text: "星巴克咖啡", confidence: 0.98, boundingBox: CGRect(x: 10, y: 10, width: 100, height: 20)),
                TextBlock(text: "¥35.00", confidence: 0.92, boundingBox: CGRect(x: 10, y: 35, width: 60, height: 20))
            ]
        )
        
        return RecognitionResult(
            ocrData: testOCRData,
            amounts: [35.00],
            merchants: ["星巴克咖啡"],
            suggestedCategory: "餐饮",
            categoryConfidence: 0.85,
            isValid: true
        )
    }
    
    public var merchantName: String? {
        return merchants.first
    }
    
    // 总金额
    public var totalAmount: Double {
        return amounts.reduce(0, +)
    }
    
    // 最佳描述
    public var bestDescription: String {
        return merchantName ?? "未知商家"
    }
    
    // 检测到的日期
    public var detectedDate: Date? {
        return timestamp
    }
    
    // 支付方式（从OCR文本中提取）
    public var paymentMethod: String? {
        let text = ocrData.text.lowercased()
        if text.contains("微信") || text.contains("wechat") {
            return "微信支付"
        } else if text.contains("支付宝") || text.contains("alipay") {
            return "支付宝"
        } else if text.contains("银行卡") || text.contains("card") {
            return "银行卡"
        } else if text.contains("现金") || text.contains("cash") {
            return "现金"
        }
        return nil
    }
    
    // 原始文本
    public var rawText: String {
        return ocrData.text
    }
}

// MARK: - Auto Recognition Service Protocol
public protocol AutoRecognitionServiceProtocol: ObservableObject {
    var state: AutoRecognitionState { get }
    
    func startRecognition() async
    func stopRecognition()
    func setEnabled(_ enabled: Bool)
    func setTestMode(_ enabled: Bool)
    func clearResults()
    func reset()
    
    // Additional methods needed by ViewModels
    func toggleEnabled()
    func toggleTestMode()
    func manualTrigger()
    func cancelRecognition()
    func retryRecognition()
    func confirmResult()
    func showTutorial()
    func completeTutorial()
    func clearLogs()
} 