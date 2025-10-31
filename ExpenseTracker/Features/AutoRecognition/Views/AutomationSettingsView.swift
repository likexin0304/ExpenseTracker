import SwiftUI

/// 自动化设置界面
struct AutomationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AutomationSettings
    @State private var showingPresetAlert = false
    @State private var selectedPreset: AutomationSettings?
    
    init() {
        // ✅ 从UserDefaults加载保存的设置，如果没有则使用默认值
        if let savedData = UserDefaults.standard.data(forKey: "automationSettings"),
           let decoded = try? JSONDecoder().decode(AutomationSettings.self, from: savedData) {
            _settings = State(initialValue: decoded)
            print("✅ 从UserDefaults加载自动化设置")
        } else {
            // 使用AutoOCRViewModel的默认设置
            let defaultSettings = AutoOCRViewModel().automationSettings
            _settings = State(initialValue: defaultSettings)
            print("⚠️ 使用默认自动化设置")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 自动化级别选择
                automationLevelSection
                
                // 智能模式设置
                if settings.level == .smart {
                    smartModeSection
                }
                
                // 通知设置
                notificationSection
                
                // 高级设置
                advancedSection
                
                // 预设配置
                presetSection
            }
            .navigationTitle("自动化设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .disabled(!settings.isValid)
                }
            }
        }
        .alert("应用预设配置", isPresented: $showingPresetAlert) {
            Button("取消", role: .cancel) {
                selectedPreset = nil
            }
            Button("应用") {
                if let preset = selectedPreset {
                    settings = preset
                }
                selectedPreset = nil
            }
        } message: {
            if let preset = selectedPreset {
                Text("将应用\(preset.summary)配置，这将覆盖当前设置。")
            }
        }
    }
    
    // MARK: - 自动化级别选择
    
    private var automationLevelSection: some View {
        Section(header: Text("自动化级别"), footer: Text(settings.level.description).foregroundColor(.secondary)) {
            ForEach(AutomationLevel.allCases, id: \.self) { level in
                automationLevelRow(level)
            }
        }
    }
    
    private func automationLevelRow(_ level: AutomationLevel) -> some View {
        HStack {
            Image(systemName: level.icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayName)
                    .font(.body)
                Text(level.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if settings.level == level {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            settings.level = level
        }
    }
    
    // MARK: - 智能模式设置
    
    private var smartModeSection: some View {
        Section(header: Text("智能模式设置"), footer: Text("高于此置信度的识别结果将自动创建支出记录，低于此值的需要用户确认。").foregroundColor(.secondary)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("置信度阈值")
                    Spacer()
                    Text("\(Int(settings.confidenceThreshold * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.confidenceThreshold, in: 0.5...0.95, step: 0.05) {
                    Text("置信度阈值")
                } minimumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("95%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 通知设置
    
    private var notificationSection: some View {
        Section(header: Text("通知设置"), footer: settings.enableNotifications ? Text("确保在系统设置中允许ExpenseTracker发送通知。").foregroundColor(.secondary) : nil) {
            Toggle("启用通知", isOn: $settings.enableNotifications)
            
            if settings.enableNotifications {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.orange)
                    Text("成功创建支出记录时通知")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    Text("需要用户确认时通知")
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - 高级设置
    
    private var advancedSection: some View {
        Section(header: Text("高级设置"), footer: VStack(alignment: .leading, spacing: 4) {
            Text("• 背敲检测：轻敲手机背面3次触发识别")
            Text("• 触发延迟：背敲检测到快捷指令执行的延迟时间")
            Text("• 调试模式：显示详细的处理信息")
        }.font(.caption).foregroundColor(.secondary)) {
            Toggle("启用背敲检测", isOn: $settings.enableBackTap)
            
            if settings.enableBackTap {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("触发延迟")
                        Spacer()
                        Text("\(settings.triggerDelay, specifier: "%.1f")秒")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.triggerDelay, in: 0.1...3.0, step: 0.1) {
                        Text("触发延迟")
                    } minimumValueLabel: {
                        Text("0.1s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("3.0s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Toggle("保存处理历史", isOn: $settings.saveHistory)
            
            if settings.saveHistory {
                Stepper("最大历史记录: \(settings.maxHistoryCount)", 
                       value: $settings.maxHistoryCount, 
                       in: 10...200, 
                       step: 10)
            }
            
            Toggle("启用调试模式", isOn: $settings.debugMode)
        }
    }
    
    // MARK: - 预设配置
    
    private var presetSection: some View {
        Section(header: Text("预设配置"), footer: Text("选择预设配置可以快速应用常用设置组合。").foregroundColor(.secondary)) {
            ForEach([
                AutomationSettings.basic,
                AutomationSettings.smart,
                AutomationSettings.advanced
            ], id: \.summary) { preset in
                Button(action: {
                    selectedPreset = preset
                    showingPresetAlert = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.body)
                            Text(preset.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    // MARK: - 保存设置
    
    private func saveSettings() {
        print("💾 保存自动化设置")
        
        // ✅ 1. 从UserDefaults读取旧设置，用于比较
        var oldBackTapEnabled = false
        if let savedData = UserDefaults.standard.data(forKey: "automationSettings"),
           let oldSettings = try? JSONDecoder().decode(AutomationSettings.self, from: savedData) {
            oldBackTapEnabled = oldSettings.enableBackTap
            print("📖 读取旧设置: enableBackTap = \(oldBackTapEnabled)")
        } else {
            print("⚠️ 未找到旧设置，使用默认值")
        }
        
        let newBackTapEnabled = settings.enableBackTap
        
        // ✅ 2. 保存设置到UserDefaults（持久化）
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "automationSettings")
            print("✅ 设置已保存到UserDefaults")
        } else {
            print("❌ 设置编码失败")
        }
        
        // ✅ 3. 同步到AutoOCRViewModel（如果其他地方在使用）
        let ocrViewModel = AutoOCRViewModel()
        ocrViewModel.updateAutomationSettings(settings)
        print("✅ 设置已同步到AutoOCRViewModel")
        
        // ✅ 4. 如果背敲检测开关发生变化，启用/禁用BackTapService
        if oldBackTapEnabled != newBackTapEnabled {
            print("🔄 背敲检测状态变化: \(oldBackTapEnabled) -> \(newBackTapEnabled)")
            handleBackTapToggle(enabled: newBackTapEnabled)
        } else {
            print("ℹ️ 背敲检测状态未变化: \(newBackTapEnabled)")
            // 即使状态未变化，也确保服务状态正确
            if newBackTapEnabled {
                // 如果应该启用但未启用，重新启用
                if !BackTapService.shared.isEnabled {
                    handleBackTapToggle(enabled: true)
                }
            } else {
                // 如果应该禁用但已启用，禁用
                if BackTapService.shared.isEnabled {
                    handleBackTapToggle(enabled: false)
                }
            }
        }
        
        print("✅ 自动化设置已保存并生效")
        dismiss()
    }
    
    /// 处理背面敲击开关切换
    private func handleBackTapToggle(enabled: Bool) {
        print("🔄 背面敲击检测开关: \(enabled ? "启用" : "禁用")")
        
        if enabled {
            // ✅ 启用背面敲击检测
            BackTapService.shared.enableBackTapDetection {
                print("🎯 背面敲击检测触发")
                Task { @MainActor in
                    print("🚀 开始自动识别流程")
                    AutoRecognitionViewModel.shared.isEnabled = true
                    AutoRecognitionViewModel.shared.manualTrigger()
                }
            }
            
            // ✅ 同时启用自动识别功能
            AutoRecognitionViewModel.shared.isEnabled = true
            
            // ✅ 验证服务状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if BackTapService.shared.isEnabled {
                    print("✅ 背面敲击检测服务状态验证: 已启用")
                    print("✅ 自动识别功能状态: \(AutoRecognitionViewModel.shared.isEnabled ? "已启用" : "未启用")")
                } else {
                    print("❌ 警告: 背面敲击检测服务未正确启用")
                }
            }
            
            print("✅ 背面敲击检测和自动识别功能已启用")
        } else {
            // ✅ 禁用背面敲击检测
            BackTapService.shared.disableBackTapDetection()
            
            // ✅ 同时禁用自动识别功能（可选，也可以保持启用）
            // AutoRecognitionViewModel.shared.isEnabled = false
            
            print("❌ 背面敲击检测已禁用（自动识别功能保持当前状态）")
        }
    }
}

#Preview {
    AutomationSettingsView()
} 