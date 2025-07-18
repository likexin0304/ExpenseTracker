import SwiftUI

/// 自动识别视图
struct AutoRecognitionView: View {
    /// 视图模型
    @StateObject private var viewModel = AutoRecognitionViewModel()
    
    /// 是否显示设置
    @State private var showSettings = false
    
    /// 是否显示日志
    @State private var showLogs = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 顶部状态卡片
                statusCard
                
                // OCR服务状态卡片
                ocrServiceStatusCard
                
                // 进度指示器
                if viewModel.isProcessing {
                    progressView
                }
                
                // 结果视图
                if case .success(_) = viewModel.processingState {
                    resultView
                }
                
                // 错误视图
                if case .failed(_) = viewModel.processingState {
                    errorView
                }
                
                // 操作按钮区域
                actionButtons
                
                Spacer()
                
                // 底部信息区域
                bottomInfoArea
            }
            .padding()
            .navigationTitle("自动识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
            }
            .sheet(isPresented: $viewModel.showTutorial) {
                AutoOCRTutorialView()
                    .onDisappear {
                        viewModel.completeTutorial()
                    }
            }
            .sheet(isPresented: $showSettings) {
                AutoRecognitionSettingsView()
            }
            .sheet(isPresented: $showLogs) {
                AutoRecognitionLogsView(logs: viewModel.backTapLogs, onClear: {
                    viewModel.clearLogs()
                })
            }
        }
    }
    
    /// 状态卡片
    private var statusCard: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.statusText)
                    .font(.headline)
                
                Spacer()
                
                Toggle("启用", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { _ in viewModel.toggleEnabled() }
                ))
                .labelsHidden()
            }
            
            if !viewModel.isEnabled {
                Text("启用自动识别功能以通过背面敲击快速记录支出")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
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
                Text("上次检查: \(timeAgoFormatter.localizedString(for: lastCheck, relativeTo: Date()))")
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
    
    /// 进度视图
    private var progressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .animation(.easeInOut, value: viewModel.progress)
            
            Text(viewModel.progressMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    /// 结果视图
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("识别结果")
                .font(.headline)
                .padding(.bottom, 4)
            
            if let result = viewModel.recognitionResult {
                HStack {
                    Text("商家:")
                        .foregroundColor(.secondary)
                    Text(result.merchantName)
                        .bold()
                    Spacer()
                }
                
                HStack {
                    Text("金额:")
                        .foregroundColor(.secondary)
                    Text("¥\(String(format: "%.2f", result.amount))")
                        .bold()
                    Spacer()
                }
                
                HStack {
                    Text("类别:")
                        .foregroundColor(.secondary)
                    Text(result.category.rawValue)
                    Spacer()
                }
                
                HStack {
                    Text("日期:")
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: result.transactionDate))
                    Spacer()
                }
                
                if let note = result.note, !note.isEmpty {
                    HStack {
                        Text("备注:")
                            .foregroundColor(.secondary)
                        Text(note)
                        Spacer()
                    }
                }
                
                HStack {
                    Text("置信度:")
                        .foregroundColor(.secondary)
                    Text("\(Int(result.confidence * 100))%")
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    /// 错误视图
    private var errorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别失败")
                .font(.headline)
                .foregroundColor(.red)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    /// 操作按钮区域
    private var actionButtons: some View {
        HStack(spacing: 16) {
            if viewModel.canCancel {
                Button(action: { viewModel.cancelRecognition() }) {
                    Label("取消", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            if viewModel.canRetry {
                Button(action: { viewModel.retryRecognition() }) {
                    Label("重试", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            
            if case .success(_) = viewModel.processingState {
                Button(action: { viewModel.confirmResult() }) {
                    Label("确认", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if viewModel.isEnabled && !viewModel.isProcessing {
                Button(action: { viewModel.manualTrigger() }) {
                    Label("手动触发", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical)
    }
    
    /// 底部信息区域
    private var bottomInfoArea: some View {
        VStack(spacing: 12) {
            if viewModel.isTestMode {
                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.orange)
                    Text("测试模式已启用")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    
                    Button(action: { viewModel.toggleTestMode() }) {
                        Text("关闭测试模式")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.ocrServiceAvailable)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            HStack {
                Button(action: { viewModel.showTutorialView() }) {
                    Label("查看教程", systemImage: "questionmark.circle")
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: { showLogs = true }) {
                    Label("查看日志", systemImage: "list.bullet")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    /// 设置按钮
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gear")
        }
    }
    
    /// 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    /// 时间前格式化器
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
}

/// 教程页面模型
struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
}

/// 自动识别日志视图
struct AutoRecognitionLogsView: View {
    /// 日志内容
    let logs: String
    
    /// 清除回调
    var onClear: () -> Void
    
    /// 环境变量
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if logs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                        
                        Text("暂无日志记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(logs)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("背面敲击日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清除") {
                        onClear()
                    }
                    .disabled(logs.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 预览
struct AutoRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        AutoRecognitionView()
    }
} 