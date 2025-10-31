import UIKit
import CoreImage
import Vision

/**
 * 图像预处理器
 * 用于提升OCR识别准确度
 * 
 * 主要功能：
 * - 对比度和亮度增强
 * - 锐化处理
 * - 去噪处理
 * - 倾斜矫正
 * - 分辨率优化
 * - 智能裁剪
 */
class ImagePreprocessor {
    
    // MARK: - 主要预处理方法
    
    /**
     * 综合预处理图像以提升OCR准确度
     * - Parameter image: 原始图像
     * - Returns: 处理后的图像
     */
    static func preprocessForOCR(_ image: UIImage) -> UIImage {
        let startTime = Date()
        print("🔧 开始图像预处理...")
        
        guard let ciImage = CIImage(image: image) else {
            print("⚠️ 无法转换为CIImage，返回原始图像")
            return image
        }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        var processedImage = ciImage
        
        // 1. 自动增强对比度和亮度
        processedImage = enhanceContrastAndBrightness(processedImage)
        
        // 2. 锐化图像
        processedImage = sharpenImage(processedImage)
        
        // 3. 去噪
        processedImage = reduceNoise(processedImage)
        
        // 4. 倾斜矫正（可选，耗时较长）
        // processedImage = correctSkew(processedImage)
        
        // 转换回UIImage
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            print("⚠️ 预处理失败，返回原始图像")
            return image
        }
        
        let result = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ 图像预处理完成，耗时: \(String(format: "%.2f", duration * 1000))ms")
        
        return result
    }
    
    // MARK: - 对比度和亮度增强
    
    /**
     * 增强图像的对比度和亮度
     * 提升文字与背景的区分度
     */
    private static func enhanceContrastAndBrightness(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey)     // 对比度 +20%
        filter.setValue(0.1, forKey: kCIInputBrightnessKey)   // 亮度 +10%
        filter.setValue(1.1, forKey: kCIInputSaturationKey)   // 饱和度 +10%
        
        return filter.outputImage ?? image
    }
    
    // MARK: - 锐化
    
    /**
     * 锐化图像，使文字边缘更清晰
     */
    private static func sharpenImage(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.8, forKey: kCIInputSharpnessKey) // 锐度
        
        return filter.outputImage ?? image
    }
    
    // MARK: - 去噪
    
    /**
     * 降低图像噪点
     */
    private static func reduceNoise(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.02, forKey: "inputNoiseLevel")
        filter.setValue(0.4, forKey: "inputSharpness")
        
        return filter.outputImage ?? image
    }
    
    // MARK: - 二值化（黑白处理）
    
    /**
     * 二值化处理，对文档类图像特别有效
     * 注意：可能会降低彩色小票的识别效果，谨慎使用
     */
    private static func binarize(_ image: CIImage) -> CIImage {
        // 转换为灰度
        guard let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") else {
            return image
        }
        grayscaleFilter.setValue(image, forKey: kCIInputImageKey)
        guard let grayImage = grayscaleFilter.outputImage else { return image }
        
        // 阈值处理
        guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else {
            return grayImage
        }
        thresholdFilter.setValue(grayImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(0.5, forKey: "inputThreshold")
        
        return thresholdFilter.outputImage ?? image
    }
    
    // MARK: - 倾斜矫正
    
    /**
     * 自动检测并矫正图像倾斜
     * 注意：此操作较耗时（200-500ms），建议按需使用
     */
    private static func correctSkew(_ image: CIImage) -> CIImage {
        print("🔄 检测图像倾斜...")
        
        let request = VNDetectTextRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                print("   未检测到文本区域")
                return image
            }
            
            // 计算平均倾斜角度
            var totalAngle: CGFloat = 0
            var validCount = 0
            
            for observation in observations {
                // 简化版：基于边界框的角度估算
                // 实际应用中可以使用更复杂的算法
                let boundingBox = observation.boundingBox
                
                // 如果宽度明显大于高度，认为是横向文本
                if boundingBox.width > boundingBox.height * 1.5 {
                    validCount += 1
                }
            }
            
            // 如果检测到足够的横向文本，认为倾斜不严重
            if validCount >= observations.count / 2 {
                print("   图像倾斜不明显，跳过矫正")
                return image
            }
            
            print("   图像可能倾斜，但简化版暂不矫正")
            // TODO: 实现更精确的倾斜角度计算和矫正
            
        } catch {
            print("⚠️ 倾斜检测失败: \(error)")
        }
        
        return image
    }
    
    // MARK: - 分辨率优化
    
    /**
     * 确保图像有足够的分辨率用于OCR
     * - Parameter image: 原始图像
     * - Parameter minSize: 最小尺寸（默认1024px）
     * - Returns: 优化后的图像
     */
    static func ensureMinimumResolution(_ image: UIImage, minSize: CGFloat = 1024) -> UIImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        // 如果分辨率已经足够，直接返回
        if maxDimension >= minSize {
            return image
        }
        
        print("📐 图像分辨率过低(\(Int(maxDimension))px)，提升至\(Int(minSize))px")
        
        // 计算缩放比例
        let scale = minSize / maxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // 使用高质量插值进行缩放
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? image
    }
    
    // MARK: - 智能裁剪
    
    /**
     * 智能裁剪：自动检测并裁剪文档区域
     * 适用于拍摄的小票、发票等场景
     */
    static func smartCrop(_ image: UIImage) -> UIImage {
        print("✂️ 尝试智能裁剪...")
        
        guard let ciImage = CIImage(image: image) else { return image }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.3
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let observation = request.results?.first {
                let boundingBox = observation.boundingBox
                
                // 转换坐标系（Vision使用归一化坐标，原点在左下角）
                let imageSize = ciImage.extent.size
                let rect = CGRect(
                    x: boundingBox.origin.x * imageSize.width,
                    y: boundingBox.origin.y * imageSize.height,
                    width: boundingBox.width * imageSize.width,
                    height: boundingBox.height * imageSize.height
                )
                
                print("   检测到文档区域: \(rect)")
                
                // 裁剪图像
                let croppedImage = ciImage.cropped(to: rect)
                
                let context = CIContext()
                if let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) {
                    print("   ✅ 智能裁剪完成")
                    return UIImage(cgImage: cgImage)
                }
            } else {
                print("   未检测到明显的文档边界，保持原图")
            }
        } catch {
            print("⚠️ 智能裁剪失败: \(error)")
        }
        
        return image
    }
    
    // MARK: - 完整预处理流程（包含所有步骤）
    
    /**
     * 完整的预处理流程
     * 包含分辨率优化、智能裁剪、图像增强
     * 注意：此流程较耗时（500-1000ms），适用于重要场景
     */
    static func fullPreprocess(_ image: UIImage) -> UIImage {
        print("🚀 开始完整预处理流程...")
        let startTime = Date()
        
        var processedImage = image
        
        // 1. 确保分辨率
        processedImage = ensureMinimumResolution(processedImage, minSize: 1024)
        
        // 2. 智能裁剪（可选）
        // processedImage = smartCrop(processedImage)
        
        // 3. 综合预处理
        processedImage = preprocessForOCR(processedImage)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ 完整预处理流程完成，总耗时: \(String(format: "%.2f", duration * 1000))ms")
        
        return processedImage
    }
    
    // MARK: - 快速预处理（优化性能）
    
    /**
     * 快速预处理模式
     * 只进行必要的增强，牺牲部分准确度换取速度
     * 耗时约150-300ms
     */
    static func fastPreprocess(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // 只进行对比度增强和轻度锐化
        var processedImage = ciImage
        processedImage = enhanceContrastAndBrightness(processedImage)
        processedImage = sharpenImage(processedImage)
        
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

