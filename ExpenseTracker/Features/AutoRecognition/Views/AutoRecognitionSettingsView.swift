import SwiftUI

/**
 * 自动识别设置界面 - Phase 4 增强版
 * 集成教程、测试和所有新功能
 */
struct AutoRecognitionSettingsView: View {
    @StateObject private var viewModel = AutoRecognitionViewModel()
    @State private var showTestView = false
    @State private var showAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // 主要功能开关
                mainToggleSection
                
                // 状态显示
                if viewModel.isEnabled {
                    statusSection
                }
                
                // 教程和帮助
                tutorialSection
                
                // 测试和调试
                testingSection
                
                // 高级设置
                advancedSettingsSection
                
                // 关于信息
                aboutSection
            }
            .navigationTitle("自动识别设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showTutorial) {
                AutoRecognitionTutorialView(isPresented: $viewModel.showTutorial)
                    .onDisappear {
                        viewModel.completeTutorial()
                    }
            }
            .sheet(isPresented: $showTestView) {
                AutoRecognitionTestView()
            }
        }
    }
    
    // MARK: - 主要功能开关
    
    private var mainToggleSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动识别功能")
                        .font(.headline)
                    
                    Text("通过背面敲击自动识别账单信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isEnabled)
                    .onChange(of: viewModel.isEnabled) { _ in
                        viewModel.toggleEnabled()
                    }
            }
            .padding(.vertical, 4)
            
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("功能控制")
        }
    }
    
    // MARK: - 状态显示
    
    private var statusSection: some View {
        Section {
            VStack(spacing: 12) {
                // 当前状态
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前状态")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.stateDisplayText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // 进度显示
                if viewModel.isProcessing {
                    VStack(spacing: 4) {
                        HStack {
                            Text(viewModel.progressMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.0f%%", viewModel.progress * 100))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                }
                
                // 操作按钮
                if viewModel.canCancel || viewModel.canRetry {
                    HStack(spacing: 12) {
                        if viewModel.canCancel {
                            Button("取消") {
                                viewModel.cancelRecognition()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if viewModel.canRetry {
                            Button("重试") {
                                viewModel.retryRecognition()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Spacer()
                        
                        Button("手动触发") {
                            viewModel.manualTrigger()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.isEnabled || viewModel.isProcessing)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("运行状态")
        }
    }
    
    // MARK: - 教程和帮助
    
    private var tutorialSection: some View {
        Section {
            Button(action: {
                viewModel.showTutorialView()
            }) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("查看使用教程")
                            .foregroundColor(.primary)
                        
                        Text("学习如何使用自动识别功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Button(action: {
                // 打开帮助文档或FAQ
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("常见问题")
                            .foregroundColor(.primary)
                        
                        Text("查看常见问题和解决方案")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("帮助和教程")
        }
    }
    
    // MARK: - 测试和调试
    
    private var testingSection: some View {
        Section {
            // 测试模式开关
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("测试模式")
                    
                    Text("启用测试和调试功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isTestMode)
                    .onChange(of: viewModel.isTestMode) { _ in
                        viewModel.toggleTestMode()
                    }
            }
            
            if viewModel.isTestMode {
                // 运行测试套件
                Button(action: {
                    Task {
                        await viewModel.runTestSuite()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("运行测试套件")
                                .foregroundColor(.primary)
                            
                            Text(viewModel.testStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.testProgress > 0 {
                            Text("\(String(format: "%.0f%%", viewModel.testProgress * 100))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 查看测试结果
                Button(action: {
                    showTestView = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("查看测试结果")
                                .foregroundColor(.primary)
                            
                            Text("查看详细的测试报告和性能指标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !viewModel.testResults.isEmpty {
                            Text("\(viewModel.testResults.count)")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .disabled(viewModel.testResults.isEmpty)
            }
        } header: {
            Text("测试和调试")
        }
    }
    
    // MARK: - 高级设置
    
    private var advancedSettingsSection: some View {
        Section {
            Button(action: {
                showAdvancedSettings = true
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("高级设置")
                            .foregroundColor(.primary)
                        
                        Text("配置识别参数和性能选项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("高级选项")
        }
    }
    
    // MARK: - 关于信息
    
    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("自动识别功能 v4.0")
                    .font(.headline)
                
                Text("通过背面敲击手势自动识别账单信息，支持OCR文字识别、智能分类推荐和数据解析。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("功能特性:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    FeatureRow(icon: "hand.tap.fill", text: "真实设备运动检测")
                    FeatureRow(icon: "eye.fill", text: "高精度OCR识别")
                    FeatureRow(icon: "brain.head.profile", text: "智能分类推荐")
                    FeatureRow(icon: "network", text: "网络重试机制")
                    FeatureRow(icon: "checkmark.shield.fill", text: "全面测试覆盖")
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("关于")
        }
    }
    
    // MARK: - 计算属性
    
    private var statusIcon: String {
        switch viewModel.state {
        case .idle:
            return "circle"
        case .waitingForConfirmation:
            return "clock"
        case .capturingScreen:
            return "camera.fill"
        case .recognizing:
            return "eye.fill"
        case .parsing:
            return "brain.head.profile"
        case .success(_):
            return "checkmark.circle.fill"
        case .failed(_):
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch viewModel.state {
        case .idle:
            return .gray
        case .waitingForConfirmation:
            return .orange
        case .capturingScreen, .recognizing, .parsing:
            return .blue
        case .success(_):
            return .green
        case .failed(_):
            return .red
        case .cancelled:
            return .orange
        }
    }
}

// MARK: - 功能特性行

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 预览

struct AutoRecognitionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AutoRecognitionSettingsView()
    }
} 