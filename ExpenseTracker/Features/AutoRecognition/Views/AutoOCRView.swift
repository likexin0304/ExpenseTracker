import SwiftUI

/// 自动化OCR主界面
struct AutoOCRView: View {
    @StateObject private var viewModel = AutoOCRViewModel()
    @State private var showingSettings = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImageSource: OCRImageSource?
    
    var body: some View {
        NavigationView {
            VStack {
                // 顶部状态区域
                statusSection
                
                // 主要内容区域
                if viewModel.isProcessing {
                    processingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if let result = viewModel.ocrResult {
                    resultView(result)
                } else {
                    emptyStateView
                }
                
                // 底部按钮区域
                buttonSection
            }
            .padding()
            .navigationTitle("智能识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AutomationSettingsView()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let image = image {
                        selectedImageSource = .gallery
                        startOCRProcess()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    if let image = image {
                        selectedImageSource = .camera
                        startOCRProcess()
                    }
                }
            }
        }
    }
    
    // MARK: - 状态区域
    
    private var statusSection: some View {
        HStack {
            if viewModel.automationSettings.enableBackTap {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.blue)
                    Text("背敲检测已启用")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if viewModel.automationSettings.debugMode {
                Text("调试模式")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 处理中视图
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在处理图像...")
                .font(.headline)
            
            Text("使用OCR技术识别图像中的文字信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 错误视图
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("处理失败")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                if let source = selectedImageSource {
                    viewModel.startOCRDetection(from: source)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 结果视图
    
    private func resultView(_ result: OCRResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 商家信息
                if let merchant = result.merchant {
                    resultSection(title: "商家", value: merchant)
                }
                
                // 金额信息
                if let amount = result.amount {
                    resultSection(title: "金额", value: String(format: "¥%.2f", amount))
                }
                
                // 日期信息
                if let date = result.date {
                    let dateString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                    resultSection(title: "日期", value: dateString)
                }
                
                // 类别信息
                if let category = result.category {
                    resultSection(title: "类别", value: category)
                }
                
                // 置信度
                if let confidence = result.confidence {
                    resultSection(title: "置信度", value: "\(Int(confidence * 100))%")
                }
                
                // 原始文本
                if !result.rawText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("识别文本")
                            .font(.headline)
                        
                        Text(result.rawText)
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // 创建支出按钮
                Button(action: {
                    viewModel.createExpenseFromOCRResult(result)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("创建支出记录")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    private func resultSection(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.headline)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.body)
            
            Spacer()
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("开始智能识别")
                .font(.headline)
            
            Text("选择一张收据或发票图片，系统将自动识别商家、金额和日期等信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部按钮区域
    
    private var buttonSection: some View {
        HStack(spacing: 20) {
            Button(action: {
                showingCamera = true
            }) {
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                    Text("拍照")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            
            Button(action: {
                showingImagePicker = true
            }) {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24))
                    Text("相册")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            
            Button(action: {
                // 历史记录功能
            }) {
                VStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                    Text("历史")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 功能方法
    
    private func startOCRProcess() {
        guard let source = selectedImageSource else { return }
        viewModel.startOCRDetection(from: source)
    }
}

// MARK: - 图像选择器

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completionHandler: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completionHandler: completionHandler)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completionHandler: (UIImage?) -> Void
        
        init(completionHandler: @escaping (UIImage?) -> Void) {
            self.completionHandler = completionHandler
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            completionHandler(image)
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completionHandler(nil)
            picker.dismiss(animated: true)
        }
    }
}

struct AutoOCRView_Previews: PreviewProvider {
    static var previews: some View {
        AutoOCRView()
    }
} 