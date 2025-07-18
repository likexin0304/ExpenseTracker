import Foundation
import SwiftUI
import Combine

class AutoOCRViewModel: ObservableObject {
    private let ocrService = AutoOCRService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isProcessing = false
    @Published var ocrResult: OCRResult?
    @Published var error: Error?
    @Published var automationSettings = AutomationSettings()
    @Published var historyItems: [AutoOCRHistoryItem] = []
    
    init() {
        // Load settings and history from the service
        setupBindings()
    }
    
    private func setupBindings() {
        // Set up bindings to the service if needed
    }
    
    func startOCRDetection(from source: OCRImageSource) {
        isProcessing = true
        error = nil
        
        ocrService.startDetection(from: source) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let ocrResult):
                    self?.ocrResult = ocrResult
                    
                    // Add to history if enabled
                    if self?.automationSettings.saveHistory == true {
                        // Crear una respuesta OCR simulada para el historial
                        let parseResponse = OCRParseResponse(
                            success: true,
                            data: OCRParseData(record: OCRRecord(
                                id: UUID().uuidString,
                                originalText: ocrResult.rawText,
                                parsedData: OCRParsedData(
                                    merchant: nil,
                                    amount: nil,
                                    date: nil,
                                    paymentMethod: nil,
                                    category: nil
                                ),
                                confidenceScore: 0.8,
                                status: "completed",
                                suggestions: nil,
                                expenseId: nil,
                                errorMessage: nil,
                                createdAt: ISO8601DateFormatter().string(from: Date())
                            )),
                            message: nil
                        )
                        
                        let historyItem = AutoOCRHistoryItem(
                            timestamp: Date(),
                            parseResult: parseResponse,
                            autoCreated: false,
                            isTest: false
                        )
                        self?.addToHistory(historyItem)
                    }
                    
                    // Handle automatic expense creation based on settings
                    self?.handleAutomaticProcessing(ocrResult)
                    
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    private func handleAutomaticProcessing(_ result: OCRResult) {
        // 由于OCRResult没有直接的confidence属性，我们从处理时间和其他因素估算一个置信度
        // 在实际实现中，可能会从其他属性或处理元数据中获取这个值
        let estimatedConfidence = estimateConfidenceFromResult(result)
        
        if automationSettings.shouldAutoCreateExpense(confidence: estimatedConfidence) {
            // Automatically create expense
            createExpenseFromOCRResult(result)
            
            // Send notification if enabled
            if automationSettings.enableNotifications {
                sendSuccessNotification(result)
            }
        } else {
            // Need user confirmation
            // This would be handled by the view showing a confirmation UI
            
            // Send notification if enabled
            if automationSettings.enableNotifications {
                sendConfirmationNeededNotification()
            }
        }
    }
    
    // 根据OCR结果估算置信度
    private func estimateConfidenceFromResult(_ result: OCRResult) -> Double {
        // 简单实现：基于处理时间和文本长度估算置信度
        // 在实际应用中，这应该基于更复杂的算法
        let baseConfidence = 0.7 // 基础置信度
        
        // 处理时间越短，置信度可能越高（假设）
        let processingTimeFactor = min(1.0, 2.0 / (result.processingTime + 0.5))
        
        // 文本长度适中可能意味着更好的结果
        let textLengthFactor = min(1.0, Double(min(result.rawText.count, 500)) / 500.0)
        
        // 组合因素计算最终置信度
        let estimatedConfidence = baseConfidence * 0.6 + processingTimeFactor * 0.2 + textLengthFactor * 0.2
        
        return min(1.0, max(0.1, estimatedConfidence)) // 确保在0.1到1.0之间
    }
    
    func createExpenseFromOCRResult(_ result: OCRResult) {
        // Implementation to create an expense from OCR result
        // This would typically call into an expense service
    }
    
    private func addToHistory(_ item: AutoOCRHistoryItem) {
        historyItems.insert(item, at: 0)
        
        // Trim history if needed
        if historyItems.count > automationSettings.maxHistoryCount {
            historyItems = Array(historyItems.prefix(automationSettings.maxHistoryCount))
        }
    }
    
    private func sendSuccessNotification(_ result: OCRResult) {
        // Implementation to send a success notification
    }
    
    private func sendConfirmationNeededNotification() {
        // Implementation to send a confirmation needed notification
    }
    
    func clearHistory() {
        historyItems.removeAll()
    }
    
    func updateAutomationSettings(_ settings: AutomationSettings) {
        self.automationSettings = settings
        // Save settings to persistent storage if needed
    }
}

// MARK: - AutomationSettings Extension

extension AutomationSettings {
    func shouldAutoCreateExpense(confidence: Double) -> Bool {
        switch level {
        case .manual:
            return false // 手动模式，从不自动创建
        case .smart:
            return confidence >= confidenceThreshold // 智能模式，根据置信度判断
        case .automatic:
            return true // 完全自动模式，总是创建
        }
    }
} 