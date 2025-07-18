import Foundation
import UIKit
import Combine

/**
 * 自动OCR服务
 * 负责处理OCR图像识别和文本处理
 */
class AutoOCRService {
    // MARK: - 单例
    static let shared = AutoOCRService()
    
    // MARK: - 依赖
    private let ocrAPIService = OCRAPIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 公共方法
    
    /**
     * 开始OCR检测
     */
    func startDetection(from source: OCRImageSource, completion: @escaping (Result<OCRResult, Error>) -> Void) {
        switch source {
        case .camera:
            processImageFromCamera(completion: completion)
        case .gallery:
            processImageFromPhotoLibrary(completion: completion)
        case .document:
            processDocumentFromURL(completion: completion)
        case .text:
            processText("示例文本", completion: completion)
        case .screenshot, .clipboard:
            // 处理截图和剪贴板
            processText("来自\(source == .screenshot ? "截图" : "剪贴板")的文本", completion: completion)
        case .unknown:
            processText("未知来源", completion: completion)
        }
    }
    
    /**
     * 处理OCR图像
     */
    func processImage(_ image: UIImage, source: OCRImageSource = .camera, completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 开始计时
        let startTime = Date()
        
        // 调用OCR API服务处理图像
        ocrAPIService.processImage(image)
            .sink(receiveCompletion: { completionResult in
                switch completionResult {
                case .finished:
                    break
                case .failure(let error):
                    completion(.failure(error))
                }
            }, receiveValue: { response in
                // 计算处理时间
                let processingTime = Date().timeIntervalSince(startTime)
                
                // 创建OCR结果
                let result = OCRResult(
                    rawText: response.data?.record.originalText ?? "",
                    parsedData: ["record": response.data?.record as Any],
                    sourceImage: image,
                    source: source,
                    timestamp: Date(),
                    processingTime: processingTime
                )
                
                completion(.success(result))
            })
            .store(in: &cancellables)
    }
    
    /**
     * 处理OCR文本
     */
    func processText(_ text: String, completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 开始计时
        let startTime = Date()
        
        // 调用OCR API服务处理文本
        ocrAPIService.parseText(text)
            .sink(receiveCompletion: { completionResult in
                switch completionResult {
                case .finished:
                    break
                case .failure(let error):
                    completion(.failure(error))
                }
            }, receiveValue: { response in
                // 计算处理时间
                let processingTime = Date().timeIntervalSince(startTime)
                
                // 创建OCR结果
                let result = OCRResult(
                    rawText: text,
                    parsedData: ["record": response.data?.record as Any],
                    sourceImage: nil,
                    source: .text,
                    timestamp: Date(),
                    processingTime: processingTime
                )
                
                completion(.success(result))
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 私有方法
    
    /**
     * 从相机处理图像
     */
    private func processImageFromCamera(completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 在实际应用中，这里会调用相机API
        // 这里我们使用模拟数据
        simulateOCRProcessing(text: "咖啡厅 2024-07-15 ¥35.50 现金支付", completion: completion)
    }
    
    /**
     * 从相册处理图像
     */
    private func processImageFromPhotoLibrary(completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 在实际应用中，这里会调用相册API
        // 这里我们使用模拟数据
        simulateOCRProcessing(text: "超市 2024-07-14 ¥128.75 微信支付", completion: completion)
    }
    
    /**
     * 从URL处理文档
     */
    private func processDocumentFromURL(completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 在实际应用中，这里会读取并处理文档
        // 这里我们使用模拟数据
        simulateOCRProcessing(text: "餐厅 2024-07-13 ¥245.00 信用卡支付", completion: completion)
    }
    
    /**
     * 模拟OCR处理
     */
    private func simulateOCRProcessing(text: String, completion: @escaping (Result<OCRResult, Error>) -> Void) {
        // 模拟网络延迟
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // 创建OCR结果
            let result = OCRResult(
                rawText: text,
                processingTime: Double.random(in: 0.5...2.0),
                timestamp: Date()
            )
            
            completion(.success(result))
        }
    }
} 