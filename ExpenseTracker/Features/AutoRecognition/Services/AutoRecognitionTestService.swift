import Foundation
import SwiftUI
import Combine

/**
 * 自动识别功能测试服务 - Phase 4
 * 提供端到端测试、性能监控和质量评估
 */
class AutoRecognitionTestService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 测试状态
    @Published var testStatus: TestStatus = .idle
    
    /// 测试进度
    @Published var testProgress: Double = 0.0
    
    /// 测试结果
    @Published var testResults: [TestResult] = []
    
    /// 性能指标
    @Published var performanceMetrics: PerformanceMetrics?
    
    // MARK: - Private Properties
    
    /// 测试用例
    private let testCases: [TestCase] = [
        TestCase(
            name: "基础OCR识别测试",
            description: "测试基本的文字识别功能",
            testType: .ocr,
            expectedDuration: 3.0
        ),
        TestCase(
            name: "金额识别准确性测试",
            description: "测试金额识别的准确性",
            testType: .amountRecognition,
            expectedDuration: 2.0
        ),
        TestCase(
            name: "商家名称识别测试",
            description: "测试商家名称识别功能",
            testType: .merchantRecognition,
            expectedDuration: 2.5
        ),
        TestCase(
            name: "分类推荐测试",
            description: "测试智能分类推荐功能",
            testType: .categoryRecommendation,
            expectedDuration: 1.5
        ),
        TestCase(
            name: "端到端流程测试",
            description: "测试完整的识别流程",
            testType: .endToEnd,
            expectedDuration: 10.0
        ),
        TestCase(
            name: "性能压力测试",
            description: "测试系统在高负载下的表现",
            testType: .performance,
            expectedDuration: 15.0
        )
    ]
    
    /// 测试数据
    private let testData = TestDataProvider()
    
    /// 性能监控器
    private let performanceMonitor = PerformanceMonitor()
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = AutoRecognitionTestService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /**
     * 运行完整测试套件
     */
    func runFullTestSuite() async {
        await MainActor.run {
            testStatus = .running
            testProgress = 0.0
            testResults = []
            performanceMetrics = nil
        }
        
        performanceMonitor.startMonitoring()
        
        let totalTests = testCases.count
        
        for (index, testCase) in testCases.enumerated() {
            print("🧪 开始测试: \(testCase.name)")
            
            let result = await runSingleTest(testCase)
            
            await MainActor.run {
                testResults.append(result)
                testProgress = Double(index + 1) / Double(totalTests)
            }
            
            // 测试间隔
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        let metrics = performanceMonitor.stopMonitoring()
        
        await MainActor.run {
            performanceMetrics = metrics
            testStatus = .completed
            testProgress = 1.0
        }
        
        print("✅ 测试套件完成")
        generateTestReport()
    }
    
    /**
     * 运行单个测试
     */
    func runSingleTest(_ testCase: TestCase) async -> TestResult {
        let startTime = Date()
        
        switch testCase.testType {
        case .ocr:
            return await runOCRTest(testCase, startTime: startTime)
        case .amountRecognition:
            return await runAmountRecognitionTest(testCase, startTime: startTime)
        case .merchantRecognition:
            return await runMerchantRecognitionTest(testCase, startTime: startTime)
        case .categoryRecommendation:
            return await runCategoryRecommendationTest(testCase, startTime: startTime)
        case .endToEnd:
            return await runEndToEndTest(testCase, startTime: startTime)
        case .performance:
            return await runPerformanceTest(testCase, startTime: startTime)
        }
    }
    
    /**
     * 获取测试报告
     */
    func getTestReport() -> TestReport {
        let passedTests = testResults.filter { $0.status == .passed }.count
        let failedTests = testResults.filter { $0.status == .failed }.count
        let totalDuration = testResults.reduce(0) { $0 + $1.duration }
        
        return TestReport(
            totalTests: testResults.count,
            passedTests: passedTests,
            failedTests: failedTests,
            successRate: testResults.isEmpty ? 0 : Double(passedTests) / Double(testResults.count),
            totalDuration: totalDuration,
            performanceMetrics: performanceMetrics,
            testResults: testResults
        )
    }
    
    // MARK: - Private Test Methods
    
    /**
     * OCR识别测试
     */
    private func runOCRTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImage = testData.getTestImage(for: TestDataProvider.TestImageType.receipt)
        
        let ocrResult = await OCRService.shared.recognizeText(from: testImage)
        
        switch ocrResult {
        case .success(let ocrData):
            let isValid = !ocrData.textBlocks.isEmpty && ocrData.confidence > 0.5
            
            return TestResult(
                testCase: testCase,
                status: isValid ? .passed : .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: isValid ? nil : "OCR识别质量不达标",
                metrics: TestMetrics(
                    accuracy: Double(ocrData.confidence),
                    processingTime: Date().timeIntervalSince(startTime),
                    memoryUsage: performanceMonitor.getCurrentMemoryUsage()
                )
            )
        case .failure(let error):
            return TestResult(
                testCase: testCase,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription,
                metrics: nil
            )
        }
    }
    
    /**
     * 金额识别测试
     */
    private func runAmountRecognitionTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImage = testData.getTestImage(for: TestDataProvider.TestImageType.receiptWithAmount)
        let expectedAmount = testData.getExpectedAmount(for: testImage)
        
        let ocrResult = await OCRService.shared.recognizeText(from: testImage)
        
        switch ocrResult {
        case .success(let ocrData):
            let parseResult = await DataParsingService.shared.parseOCRData(ocrData)
            
            switch parseResult {
            case .success(let recognitionResult):
                let recognizedAmount = recognitionResult.amounts.first ?? 0.0
                let accuracy = calculateAmountAccuracy(
                    recognized: recognizedAmount,
                    expected: expectedAmount
                )
                
                return TestResult(
                    testCase: testCase,
                    status: accuracy > 0.9 ? .passed : .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: accuracy <= 0.9 ? "金额识别准确率不达标: \(accuracy)" : nil,
                    metrics: TestMetrics(
                        accuracy: accuracy,
                        processingTime: Date().timeIntervalSince(startTime),
                        memoryUsage: performanceMonitor.getCurrentMemoryUsage()
                    )
                )
            case .failure(let error):
                return TestResult(
                    testCase: testCase,
                    status: .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: error.localizedDescription,
                    metrics: nil
                )
            }
        case .failure(let error):
            return TestResult(
                testCase: testCase,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription,
                metrics: nil
            )
        }
    }
    
    /**
     * 商家名称识别测试
     */
    private func runMerchantRecognitionTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImage = testData.getTestImage(for: .receiptWithMerchant)
        let expectedMerchant = testData.getExpectedMerchant(for: testImage)
        
        let ocrResult = await OCRService.shared.recognizeText(from: testImage)
        
        switch ocrResult {
        case .success(let ocrData):
            let parseResult = await DataParsingService.shared.parseOCRData(ocrData)
            
            switch parseResult {
            case .success(let recognitionResult):
                let accuracy = calculateMerchantAccuracy(
                    recognized: recognitionResult.merchantName,
                    expected: expectedMerchant
                )
                
                return TestResult(
                    testCase: testCase,
                    status: accuracy > 0.8 ? .passed : .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: accuracy <= 0.8 ? "商家识别准确率不达标: \(accuracy)" : nil,
                    metrics: TestMetrics(
                        accuracy: accuracy,
                        processingTime: Date().timeIntervalSince(startTime),
                        memoryUsage: performanceMonitor.getCurrentMemoryUsage()
                    )
                )
            case .failure(let error):
                return TestResult(
                    testCase: testCase,
                    status: .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: error.localizedDescription,
                    metrics: nil
                )
            }
        case .failure(let error):
            return TestResult(
                testCase: testCase,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription,
                metrics: nil
            )
        }
    }
    
    /**
     * 分类推荐测试
     */
    private func runCategoryRecommendationTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImage = testData.getTestImage(for: .receiptWithCategory)
        let expectedCategory = testData.getExpectedCategory(for: testImage)
        
        let ocrResult = await OCRService.shared.recognizeText(from: testImage)
        
        switch ocrResult {
        case .success(let ocrData):
            let parseResult = await DataParsingService.shared.parseOCRData(ocrData)
            
            switch parseResult {
            case .success(let recognitionResult):
                let isCorrect = recognitionResult.suggestedCategory == expectedCategory
                
                return TestResult(
                    testCase: testCase,
                    status: isCorrect ? .passed : .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: isCorrect ? nil : "分类推荐不正确",
                    metrics: TestMetrics(
                        accuracy: isCorrect ? 1.0 : 0.0,
                        processingTime: Date().timeIntervalSince(startTime),
                        memoryUsage: performanceMonitor.getCurrentMemoryUsage()
                    )
                )
            case .failure(let error):
                return TestResult(
                    testCase: testCase,
                    status: .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: error.localizedDescription,
                    metrics: nil
                )
            }
        case .failure(let error):
            return TestResult(
                testCase: testCase,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription,
                metrics: nil
            )
        }
    }
    
    /**
     * 端到端测试
     */
    private func runEndToEndTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImage = testData.getTestImage(for: .completeReceipt)
        
        let ocrResult = await OCRService.shared.recognizeText(from: testImage)
        
        switch ocrResult {
        case .success(let ocrData):
            let parseResult = await DataParsingService.shared.parseOCRData(ocrData)
            
            switch parseResult {
            case .success(let recognitionResult):
                let isValid = !recognitionResult.amounts.isEmpty && 
                             recognitionResult.merchantName != nil &&
                             recognitionResult.categoryConfidence > 0.5
                
                return TestResult(
                    testCase: testCase,
                    status: isValid ? .passed : .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: isValid ? nil : "端到端流程验证失败",
                    metrics: TestMetrics(
                        accuracy: isValid ? 1.0 : 0.0,
                        processingTime: Date().timeIntervalSince(startTime),
                        memoryUsage: performanceMonitor.getCurrentMemoryUsage()
                    )
                )
            case .failure(let error):
                return TestResult(
                    testCase: testCase,
                    status: .failed,
                    duration: Date().timeIntervalSince(startTime),
                    errorMessage: error.localizedDescription,
                    metrics: nil
                )
            }
        case .failure(let error):
            return TestResult(
                testCase: testCase,
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription,
                metrics: nil
            )
        }
    }
    
    /**
     * 性能测试
     */
    private func runPerformanceTest(_ testCase: TestCase, startTime: Date) async -> TestResult {
        let testImages = testData.getMultipleTestImages(count: 10)
        var totalProcessingTime: TimeInterval = 0
        var successCount = 0
        
        for image in testImages {
            let imageStartTime = Date()
            
            let ocrResult = await OCRService.shared.recognizeText(from: image)
            
            switch ocrResult {
            case .success(let ocrData):
                let parseResult = await DataParsingService.shared.parseOCRData(ocrData)
                
                switch parseResult {
                case .success(_):
                    totalProcessingTime += Date().timeIntervalSince(imageStartTime)
                    successCount += 1
                case .failure(let error):
                    print("性能测试中的解析错误: \(error)")
                }
            case .failure(let error):
                print("性能测试中的OCR错误: \(error)")
            }
        }
        
        let averageProcessingTime = totalProcessingTime / Double(testImages.count)
        let successRate = Double(successCount) / Double(testImages.count)
        
        // 性能标准：平均处理时间 < 5秒，成功率 > 80%
        let isPerformanceGood = averageProcessingTime < 5.0 && successRate > 0.8
        
        return TestResult(
            testCase: testCase,
            status: isPerformanceGood ? .passed : .failed,
            duration: Date().timeIntervalSince(startTime),
            errorMessage: isPerformanceGood ? nil : "性能不达标",
            metrics: TestMetrics(
                accuracy: successRate,
                processingTime: averageProcessingTime,
                memoryUsage: performanceMonitor.getCurrentMemoryUsage()
            )
        )
    }
    
    // MARK: - Helper Methods
    
    /**
     * 计算金额识别准确率
     */
    private func calculateAmountAccuracy(recognized: Double, expected: Double) -> Double {
        guard expected > 0 else { return 0 }
        let difference = abs(recognized - expected)
        let accuracy = max(0, 1 - (difference / expected))
        return accuracy
    }
    
    /**
     * 计算商家名称识别准确率
     */
    private func calculateMerchantAccuracy(recognized: String?, expected: String) -> Double {
        guard let recognized = recognized else { return 0 }
        
        // 使用编辑距离计算相似度
        let distance = levenshteinDistance(recognized.lowercased(), expected.lowercased())
        let maxLength = max(recognized.count, expected.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return max(0, 1.0 - Double(distance) / Double(maxLength))
    }
    
    /**
     * 计算编辑距离
     */
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
    
    /**
     * 生成测试报告
     */
    private func generateTestReport() {
        let report = getTestReport()
        print("📊 测试报告:")
        print("总测试数: \(report.totalTests)")
        print("通过: \(report.passedTests)")
        print("失败: \(report.failedTests)")
        print("成功率: \(String(format: "%.1f%%", report.successRate * 100))")
        print("总耗时: \(String(format: "%.2f秒", report.totalDuration))")
        
        if let metrics = report.performanceMetrics {
            print("性能指标:")
            print("- 平均CPU使用率: \(String(format: "%.1f%%", metrics.averageCPUUsage))")
            print("- 峰值内存使用: \(String(format: "%.1fMB", metrics.peakMemoryUsage))")
        }
    }
}

// MARK: - Supporting Types

/**
 * 测试状态
 */
enum TestStatus {
    case idle
    case running
    case completed
    case failed
}

/**
 * 测试用例
 */
struct TestCase {
    let name: String
    let description: String
    let testType: TestType
    let expectedDuration: TimeInterval
}

/**
 * 测试类型
 */
enum TestType {
    case ocr
    case amountRecognition
    case merchantRecognition
    case categoryRecommendation
    case endToEnd
    case performance
}

/**
 * 测试结果
 */
struct TestResult {
    let testCase: TestCase
    let status: TestResultStatus
    let duration: TimeInterval
    let errorMessage: String?
    let metrics: TestMetrics?
}

/**
 * 测试结果状态
 */
enum TestResultStatus {
    case passed
    case failed
    case skipped
}

/**
 * 测试指标
 */
struct TestMetrics {
    let accuracy: Double
    let processingTime: TimeInterval
    let memoryUsage: Double
}

/**
 * 测试报告
 */
struct TestReport {
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let successRate: Double
    let totalDuration: TimeInterval
    let performanceMetrics: PerformanceMetrics?
    let testResults: [TestResult]
}

/**
 * 性能指标
 */
struct PerformanceMetrics {
    let averageCPUUsage: Double
    let peakMemoryUsage: Double
    let averageResponseTime: TimeInterval
    let totalOperations: Int
}

/**
 * 性能监控器
 */
class PerformanceMonitor {
    private var startTime: Date?
    private var cpuUsages: [Double] = []
    private var memoryUsages: [Double] = []
    
    func startMonitoring() {
        startTime = Date()
        cpuUsages = []
        memoryUsages = []
    }
    
    func stopMonitoring() -> PerformanceMetrics {
        let averageCPU = cpuUsages.isEmpty ? 0 : cpuUsages.reduce(0, +) / Double(cpuUsages.count)
        let peakMemory = memoryUsages.max() ?? 0
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        return PerformanceMetrics(
            averageCPUUsage: averageCPU,
            peakMemoryUsage: peakMemory,
            averageResponseTime: duration,
            totalOperations: cpuUsages.count
        )
    }
    
    func getCurrentMemoryUsage() -> Double {
        // 简化的内存使用计算
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // MB
            memoryUsages.append(memoryUsage)
            return memoryUsage
        }
        
        return 0
    }
}

/**
 * 测试数据提供者
 */
class TestDataProvider {
    
    enum TestImageType {
        case receipt
        case receiptWithAmount
        case receiptWithMerchant
        case receiptWithCategory
        case completeReceipt
    }
    
    // 测试数据映射
    private let testDataMap: [TestImageType: TestData] = [
        .receipt: TestData(
            imageName: "test_receipt_basic",
            expectedAmount: 0.0,
            expectedMerchant: nil,
            expectedCategory: .other
        ),
        .receiptWithAmount: TestData(
            imageName: "test_receipt_amount",
            expectedAmount: 45.80,
            expectedMerchant: nil,
            expectedCategory: .other
        ),
        .receiptWithMerchant: TestData(
            imageName: "test_receipt_merchant",
            expectedAmount: 0.0,
            expectedMerchant: "星巴克咖啡",
            expectedCategory: .food
        ),
        .receiptWithCategory: TestData(
            imageName: "test_receipt_category",
            expectedAmount: 0.0,
            expectedMerchant: nil,
            expectedCategory: .transport
        ),
        .completeReceipt: TestData(
            imageName: "test_receipt_complete",
            expectedAmount: 128.50,
            expectedMerchant: "麦当劳",
            expectedCategory: .food
        )
    ]
    
    func getTestImage(for type: TestImageType) -> UIImage {
        // 在实际应用中，这里应该从Bundle加载真实的测试图片
        // 现在返回系统图标作为占位符
        switch type {
        case .receipt:
            return createTestImage(with: "基础小票测试")
        case .receiptWithAmount:
            return createTestImage(with: "金额: ¥45.80")
        case .receiptWithMerchant:
            return createTestImage(with: "星巴克咖啡\n消费小票")
        case .receiptWithCategory:
            return createTestImage(with: "地铁交通卡\n充值记录")
        case .completeReceipt:
            return createTestImage(with: "麦当劳\n汉堡套餐 ¥128.50\n谢谢惠顾")
        }
    }
    
    func getMultipleTestImages(count: Int) -> [UIImage] {
        let types: [TestImageType] = [.receipt, .receiptWithAmount, .receiptWithMerchant, .receiptWithCategory, .completeReceipt]
        return (0..<count).map { index in
            let type = types[index % types.count]
            return getTestImage(for: type)
        }
    }
    
    func getExpectedAmount(for image: UIImage) -> Double {
        // 根据图片内容返回期望的金额
        // 在实际应用中，这里应该有更复杂的映射逻辑
        return testDataMap.values.randomElement()?.expectedAmount ?? 0.0
    }
    
    func getExpectedMerchant(for image: UIImage) -> String {
        // 根据图片内容返回期望的商家名称
        return testDataMap.values.compactMap { $0.expectedMerchant }.randomElement() ?? "测试商家"
    }
    
    func getExpectedCategory(for image: UIImage) -> ExpenseCategory {
        // 根据图片内容返回期望的分类
        return testDataMap.values.randomElement()?.expectedCategory ?? .other
    }
    
    // MARK: - Private Methods
    
    /**
     * 创建测试图片（用于演示）
     */
    private func createTestImage(with text: String) -> UIImage {
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 背景
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 边框
            UIColor.lightGray.setStroke()
            context.stroke(CGRect(origin: .zero, size: size))
            
            // 文字
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            let textRect = CGRect(x: 20, y: 50, width: size.width - 40, height: size.height - 100)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

/**
 * 测试数据结构
 */
private struct TestData {
    let imageName: String
    let expectedAmount: Double
    let expectedMerchant: String?
    let expectedCategory: ExpenseCategory
} 