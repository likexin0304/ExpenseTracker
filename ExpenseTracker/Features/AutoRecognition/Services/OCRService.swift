import UIKit
import Vision
import Combine
import Foundation

/**
 * OCR文字识别服务 - Phase 3 优化版本
 * 负责从图像中识别文字内容
 */
class OCRService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 是否正在识别
    @Published var isRecognizing: Bool = false
    
    /// 识别进度 (0.0 - 1.0)
    @Published var recognitionProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    /// 识别队列
    private let recognitionQueue = DispatchQueue(label: "com.expensetracker.ocr", qos: .userInitiated)
    
    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()
    
    /// OCR配置
    private let configuration = OCRConfiguration()
    
    /// 性能监控
    private var performanceMonitor = OCRPerformanceMonitor()
    
    // MARK: - Singleton
    
    static let shared = OCRService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /**
     * 识别图像中的文字并调用后端API解析 - 集成后端API版本
     * - Parameter image: 要识别的图像
     * - Returns: OCR识别和解析结果
     */
    func recognizeTextWithAPI(from image: UIImage) async -> Result<OCRRecord, AutoRecognitionError> {
        print("🔍 开始OCR文字识别和后端解析")
        let startTime = Date()
        
        await MainActor.run {
            isRecognizing = true
            recognitionProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isRecognizing = false
                recognitionProgress = 1.0
            }
        }
        
        // 第一步：本地OCR识别文字
        let ocrResult = await withCheckedContinuation { continuation in
            recognitionQueue.async {
                self.performOCRRecognition(image: image) { result in
                    continuation.resume(returning: result)
                }
            }
        }
        
        // 更新进度
        await MainActor.run {
            recognitionProgress = 0.6
        }
        
        // 第二步：如果OCR成功，调用后端API解析
        switch ocrResult {
        case .success(let ocrData):
            print("✅ 本地OCR识别成功，开始后端解析")
            
            // 调用后端API解析文本
            do {
                let parseData = try await withCheckedThrowingContinuation { continuation in
                    OCRAPIService.shared.parseOCRText(ocrData.text)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { parseData in
                                continuation.resume(returning: parseData)
                            }
                        )
                        .store(in: &self.cancellables)
                }
                
                let record = parseData.record
                
                await MainActor.run {
                    recognitionProgress = 1.0
                }
                
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceMonitor.recordRecognition(
                    success: true,
                    processingTime: processingTime
                )
                
                print("✅ 后端解析成功")
                return .success(record)
                
            } catch {
                print("❌ 后端解析失败: \(error)")
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceMonitor.recordRecognition(
                    success: false,
                    processingTime: processingTime
                )
                
                return .failure(.networkError("后端解析失败: \(error.localizedDescription)"))
            }
            
        case .failure(let error):
            print("❌ 本地OCR识别失败: \(error)")
            let processingTime = Date().timeIntervalSince(startTime)
            self.performanceMonitor.recordRecognition(
                success: false,
                processingTime: processingTime
            )
            return .failure(error)
        }
    }
    
    /**
     * 仅执行本地OCR识别（原始方法，保持向后兼容）
     * - Parameter image: 要识别的图像
     * - Returns: 本地OCR识别结果
     */
    func recognizeText(from image: UIImage) async -> Result<OCRData, AutoRecognitionError> {
        return await recognizeTextLocally(from: image)
    }
    
    /**
     * 仅执行本地OCR识别（不调用后端API）
     * - Parameter image: 要识别的图像
     * - Returns: 本地OCR识别结果
     */
    func recognizeTextLocally(from image: UIImage) async -> Result<OCRData, AutoRecognitionError> {
        print("🔍 开始本地OCR文字识别")
        let startTime = Date()
        
        await MainActor.run {
            isRecognizing = true
            recognitionProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isRecognizing = false
                recognitionProgress = 0.0
            }
        }
        
        return await withCheckedContinuation { continuation in
            recognitionQueue.async {
                self.performOCRRecognition(image: image) { result in
                    let processingTime = Date().timeIntervalSince(startTime)
                    self.performanceMonitor.recordRecognition(
                        success: result.isSuccess,
                        processingTime: processingTime
                    )
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /**
     * 批量识别多张图片
     * - Parameter images: 要识别的图片数组
     * - Returns: OCR识别结果数组
     */
    func recognizeText(in images: [UIImage]) async -> [Result<OCRData, AutoRecognitionError>] {
        print("🔍 开始批量OCR识别，共\(images.count)张图片")
        
        var results: [Result<OCRData, AutoRecognitionError>] = []
        
        for (index, image) in images.enumerated() {
            await MainActor.run {
                recognitionProgress = Double(index) / Double(images.count)
            }
            
            let result = await recognizeText(from: image)
            results.append(result)
        }
        
        await MainActor.run {
            recognitionProgress = 1.0
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    /**
     * 执行OCR识别 - Phase 3 优化版本
     */
    public func performOCRRecognition(
        image: UIImage,
        completion: @escaping (Result<OCRData, AutoRecognitionError>) -> Void
    ) {
        // 更新进度
        Task { @MainActor in
            recognitionProgress = 0.1
        }
        
        // 1. 图像预处理
        guard let preprocessedImage = preprocessImage(image) else {
            completion(.failure(.ocrFailed("图像预处理失败")))
            return
        }
        
        Task { @MainActor in
            recognitionProgress = 0.2
        }
        
        // 2. 创建Vision请求
        let request = createVisionRequest { [weak self] result in
            switch result {
            case .success(let ocrData):
                completion(.success(ocrData))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
        Task { @MainActor in
            recognitionProgress = 0.3
        }
        
        // 3. 执行识别
        guard let cgImage = preprocessedImage.cgImage else {
            completion(.failure(.ocrFailed("无法获取图像数据")))
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ OCR识别失败: \(error.localizedDescription)")
            completion(.failure(.ocrFailed("OCR识别失败: \(error.localizedDescription)")))
        }
    }
    
    /**
     * 图像预处理 - Phase 3 新增
     */
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 调整图像大小以优化识别性能
        let targetSize = calculateOptimalSize(for: image.size)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制调整后的图像
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        // 应用图像增强滤镜
        return applyImageEnhancement(to: resizedImage) ?? resizedImage
    }
    
    /**
     * 计算最优图像尺寸
     */
    private func calculateOptimalSize(for originalSize: CGSize) -> CGSize {
        let maxDimension: CGFloat = 2048
        let minDimension: CGFloat = 512
        
        let maxOriginal = max(originalSize.width, originalSize.height)
        let minOriginal = min(originalSize.width, originalSize.height)
        
        // 如果图像太大，按比例缩小
        if maxOriginal > maxDimension {
            let scale = maxDimension / maxOriginal
            return CGSize(
                width: originalSize.width * scale,
                height: originalSize.height * scale
            )
        }
        
        // 如果图像太小，按比例放大
        if minOriginal < minDimension {
            let scale = minDimension / minOriginal
            return CGSize(
                width: originalSize.width * scale,
                height: originalSize.height * scale
            )
        }
        
        return originalSize
    }
    
    /**
     * 应用图像增强滤镜
     */
    private func applyImageEnhancement(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // 应用对比度和亮度调整
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // 增加对比度
        contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // 轻微增加亮度
        
        guard let contrastOutput = contrastFilter.outputImage else { return image }
        
        // 应用锐化滤镜
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else {
            // 如果锐化失败，返回对比度调整后的图像
            guard let outputCGImage = context.createCGImage(contrastOutput, from: contrastOutput.extent) else {
                return image
            }
            return UIImage(cgImage: outputCGImage)
        }
        
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
        sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
        
        guard let finalOutput = sharpenFilter.outputImage,
              let outputCGImage = context.createCGImage(finalOutput, from: finalOutput.extent) else {
            return image
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    /**
     * 创建Vision识别请求 - Phase 3 优化版本
     */
    private func createVisionRequest(
        completion: @escaping (Result<OCRData, AutoRecognitionError>) -> Void
    ) -> VNRecognizeTextRequest {
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            Task { @MainActor in
                self?.recognitionProgress = 0.8
            }
            
            if let error = error {
                print("❌ Vision识别错误: \(error.localizedDescription)")
                completion(.failure(.ocrFailed("Vision识别错误: \(error.localizedDescription)")))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(.ocrFailed("无法获取识别结果")))
                return
            }
            
            Task { @MainActor in
                self?.recognitionProgress = 0.9
            }
            
            // 处理识别结果
            self?.processRecognitionResults(observations, completion: completion)
        }
        
        // 配置识别参数 - Phase 3 优化
        request.recognitionLevel = .accurate // 使用高精度识别
        request.usesLanguageCorrection = true // 启用语言校正
        
        // 设置支持的语言
        if #available(iOS 16.0, *) {
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"] // 简体中文、繁体中文、英文
        } else {
            // iOS 15及以下版本的兼容处理
            request.recognitionLanguages = ["zh", "en"]
        }
        
        // 设置自定义词汇（常见的金额和商家关键词）
        if #available(iOS 15.0, *) {
            request.customWords = configuration.customWords
        }
        
        return request
    }
    
    /**
     * 处理识别结果 - Phase 3 优化版本
     */
    private func processRecognitionResults(
        _ observations: [VNRecognizedTextObservation],
        completion: @escaping (Result<OCRData, AutoRecognitionError>) -> Void
    ) {
        var textBlocks: [OCRTextBlock] = []
        var overallConfidence: Float = 0.0
        var totalConfidence: Float = 0.0
        var validObservations = 0
        
        for observation in observations {
            // 获取最佳候选文本
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // 过滤掉置信度过低的文本
            guard confidence > configuration.minimumConfidence else { continue }
            
            // 分析文本类型
            let textType = analyzeTextType(text)
            
            // 获取文本边界框
            let boundingBox = observation.boundingBox
            
            let textBlock = OCRTextBlock(
                text: text,
                confidence: Double(confidence),
                boundingBox: boundingBox,
                textType: textType
            )
            
            textBlocks.append(textBlock)
            totalConfidence += confidence
            validObservations += 1
        }
        
        // 计算整体置信度
        overallConfidence = validObservations > 0 ? totalConfidence / Float(validObservations) : 0.0
        
        Task { @MainActor in
            recognitionProgress = 1.0
        }
        
        // 验证识别结果
        guard !textBlocks.isEmpty else {
            completion(.failure(.ocrFailed("未识别到任何文本")))
            return
        }
        
        guard overallConfidence > configuration.minimumOverallConfidence else {
            completion(.failure(.ocrFailed("识别置信度过低: \(String(format: "%.2f", overallConfidence))")))
            return
        }
        
        // 后处理：文本清理和优化
        let cleanedTextBlocks = postProcessTextBlocks(textBlocks)
        
        let ocrData = OCRData(
            text: cleanedTextBlocks.map { $0.text }.joined(separator: " "),
            confidence: Double(overallConfidence),
            textBlocks: cleanedTextBlocks.map { TextBlock(text: $0.text, confidence: $0.confidence, boundingBox: $0.boundingBox) }
        )
        
        print("✅ OCR识别完成")
        print("📝 识别到 \(cleanedTextBlocks.count) 个文本块")
        print("🎯 整体置信度: \(String(format: "%.2f", overallConfidence))")
        print("📄 识别文本: \(cleanedTextBlocks.map { $0.text }.joined(separator: " | "))")
        
        completion(.success(ocrData))
    }
    
    /**
     * 分析文本类型 - Phase 3 新增
     */
    private func analyzeTextType(_ text: String) -> OCRTextType {
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 金额模式
        let amountPatterns = [
            "^[¥$€]?[0-9,]+\\.?[0-9]*$",
            "^[0-9,]+\\.[0-9]{2}元?$",
            "^[0-9,]+元$"
        ]
        
        for pattern in amountPatterns {
            if normalizedText.range(of: pattern, options: .regularExpression) != nil {
                return .amount
            }
        }
        
        // 货币符号
        if normalizedText.contains("¥") || normalizedText.contains("$") || normalizedText.contains("€") {
            return .currency
        }
        
        // 日期模式
        let datePatterns = [
            "\\d{4}-\\d{2}-\\d{2}",
            "\\d{4}/\\d{2}/\\d{2}",
            "\\d{4}年\\d{1,2}月\\d{1,2}日"
        ]
        
        for pattern in datePatterns {
            if normalizedText.range(of: pattern, options: .regularExpression) != nil {
                return .date
            }
        }
        
        // 时间模式
        if normalizedText.range(of: "\\d{1,2}:\\d{2}", options: .regularExpression) != nil {
            return .time
        }
        
        // 商家名称（通常较长且包含特定关键词）
        let merchantKeywords = ["店", "餐厅", "公司", "有限", "超市", "商场", "中心"]
        if merchantKeywords.contains(where: { normalizedText.contains($0) }) && text.count > 3 {
            return .merchant
        }
        
        // 标题（通常较短且在顶部）
        if text.count <= 10 && !normalizedText.contains(" ") {
            return .header
        }
        
        return .general
    }
    
    /**
     * 后处理文本块 - Phase 3 新增
     */
    private func postProcessTextBlocks(_ textBlocks: [OCRTextBlock]) -> [OCRTextBlock] {
        return textBlocks.compactMap { block in
            let cleanedText = cleanText(block.text)
            
            // 过滤掉过短或无意义的文本
            guard cleanedText.count >= 1 && !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            
            return OCRTextBlock(
                text: cleanedText,
                confidence: block.confidence,
                boundingBox: block.boundingBox,
                textType: block.textType
            )
        }
    }
    
    /**
     * 清理文本 - Phase 3 新增
     */
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // 移除多余的空白字符
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 修正常见的OCR错误
        let corrections = [
            "O": "0", // O误识别为0
            "l": "1", // l误识别为1
            "S": "5", // S误识别为5
            "G": "6", // G误识别为6
            "B": "8", // B误识别为8
        ]
        
        // 应用修正
        for (wrong, correct) in corrections {
            cleaned = cleaned.replacingOccurrences(of: wrong, with: correct)
        }
        
        return cleaned
    }
}

// MARK: - Supporting Types

/**
 * OCR配置 - Phase 3 新增
 */
struct OCRConfiguration {
    /// 最小文本置信度
    let minimumConfidence: Float = 0.3
    
    /// 最小整体置信度
    let minimumOverallConfidence: Float = 0.5
    
    /// 自定义词汇
    let customWords: [String] = [
        // 金额相关
        "元", "¥", "$", "€", "总计", "合计", "应付", "实付", "小计",
        // 商家相关
        "餐厅", "超市", "商场", "药店", "加油站", "停车场",
        // 支付相关
        "微信", "支付宝", "银行卡", "现金", "刷卡"
    ]
}

/**
 * OCR性能监控 - Phase 3 新增
 */
class OCRPerformanceMonitor {
    private var recognitionCount = 0
    private var successCount = 0
    private var totalProcessingTime: TimeInterval = 0
    
    func recordRecognition(success: Bool, processingTime: TimeInterval) {
        recognitionCount += 1
        totalProcessingTime += processingTime
        
        if success {
            successCount += 1
        }
        
        // 每10次识别输出一次统计
        if recognitionCount % 10 == 0 {
            let successRate = Double(successCount) / Double(recognitionCount) * 100
            let avgTime = totalProcessingTime / Double(recognitionCount) * 1000
            
            print("📊 OCR性能统计:")
            print("   识别次数: \(recognitionCount)")
            print("   成功率: \(String(format: "%.1f", successRate))%")
            print("   平均耗时: \(String(format: "%.1f", avgTime))ms")
        }
    }
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
} 