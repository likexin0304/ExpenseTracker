# OCR功能错误处理改进日志

## 问题概述

在iOS应用ExpenseTracker中，OCR功能出现了错误处理问题。通过分析，发现OCR API端点在后端尚未部署，导致404错误，但应用没有正确处理这种情况，导致用户体验不佳。

## 改进措施

### 1. 增强OCRAPIService

- 添加了服务可用性检测机制，通过简单的健康检查来确定OCR服务是否可用
- 实现了缓存系统，避免频繁检查服务状态
- 添加了统一的错误处理，特别是针对OCR服务不可用的情况
- 提供了服务状态刷新功能，允许用户手动检查服务可用性

```swift
// 检查OCR服务状态
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
```

### 2. 改进AutoRecognitionViewModel

- 添加了ocrServiceAvailable属性来跟踪OCR服务状态
- 添加了lastOCRServiceCheck属性来记录上次检查时间
- 实现了自动切换测试模式的功能，当OCR服务不可用时
- 添加了专门处理OCR服务不可用错误的方法
- 添加了刷新OCR服务状态的功能

```swift
/// 处理OCR服务不可用错误
private func handleServiceUnavailableError() {
    processingStateText = "服务不可用"
    progress = 0.0
    progressMessage = ""
    errorMessage = "OCR服务暂时不可用，请稍后再试或使用手动添加方式"
    hasRecognitionResult = false
    currentAutoExpenseResult = nil
    ocrServiceAvailable = false
    
    // 如果不是测试模式，自动切换到测试模式
    if !isTestMode {
        isTestMode = true
        errorMessage = "OCR服务暂时不可用，已自动切换到测试模式"
    }
    
    // 显示友好提示
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        self.processingStateText = "待机"
        // 保留错误信息，让用户知道为什么功能被禁用
    }
}
```

### 3. 更新AutoRecognitionView

- 添加了OCR服务状态卡片，显示服务可用性状态
- 添加了刷新按钮，允许用户手动检查OCR服务状态
- 添加了测试模式切换按钮，方便用户在服务不可用时使用测试模式
- 改进了错误提示，使其更加清晰明了

```swift
/// OCR服务状态卡片
private var ocrServiceStatusCard: some View {
    VStack(spacing: 10) {
        HStack {
            Circle()
                .fill(viewModel.ocrServiceAvailable ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            
            Text("OCR服务状态")
                .font(.headline)
            
            Spacer()
            
            Text(viewModel.ocrServiceAvailable ? "可用" : "不可用")
                .font(.subheadline)
                .foregroundColor(viewModel.ocrServiceAvailable ? .green : .orange)
            
            Button(action: { viewModel.refreshOCRServiceAvailability() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .disabled(viewModel.isProcessing)
        }
        
        if let lastCheck = viewModel.lastOCRServiceCheck {
            Text("上次检查: \(timeAgoFormatter.string(from: lastCheck, to: Date()))")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        if !viewModel.ocrServiceAvailable && !viewModel.isTestMode {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text("OCR服务暂时不可用，建议使用测试模式")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button(action: { viewModel.toggleTestMode() }) {
                    Text("启用测试模式")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 4)
        }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
}
```

## 结果

通过这些改进，即使OCR服务不可用，应用也能够：

1. 自动检测到OCR服务不可用的情况
2. 提供清晰的错误信息给用户
3. 自动切换到测试模式，保证功能可用性
4. 允许用户手动刷新服务状态
5. 缓存服务状态，减少不必要的网络请求

这些改进大大提高了应用的稳定性和用户体验，使用户在OCR服务不可用时仍然可以使用应用的其他功能。

## 后续工作

1. 考虑添加离线OCR功能，减少对后端服务的依赖
2. 实现更复杂的重试机制，自动在一段时间后重新检查服务状态
3. 添加用户通知，当OCR服务恢复可用时通知用户
