import SwiftUI

/// 自动OCR使用教程界面
struct AutoOCRTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private let tutorialSteps = [
        TutorialStep(
            title: "欢迎使用自动记账",
            description: "通过轻敲手机背面3次，自动截图识别账单并创建支出记录",
            icon: "hand.tap",
            content: .welcome
        ),
        TutorialStep(
            title: "设置快捷指令",
            description: "首次使用需要创建iOS快捷指令，用于自动截图",
            icon: "shortcuts",
            content: .shortcut
        ),
        TutorialStep(
            title: "启用背面轻点",
            description: "在设置中启用\"背面轻点\"功能，选择\"轻点三下\"",
            icon: "hand.tap.fill",
            content: .backTap
        ),
        TutorialStep(
            title: "选择自动化级别",
            description: "根据需要选择完全自动、智能自动或手动确认模式",
            icon: "brain.head.profile",
            content: .automation
        ),
        TutorialStep(
            title: "开始使用",
            description: "现在您可以轻敲手机背面3次来自动识别账单了！",
            icon: "checkmark.circle",
            content: .usage
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 进度指示器
                progressIndicator
                
                // 教程内容
                TabView(selection: $currentStep) {
                    ForEach(Array(tutorialSteps.enumerated()), id: \.offset) { index, step in
                        tutorialStepView(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 导航按钮
                navigationButtons
            }
            .navigationTitle("使用教程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳过") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 进度指示器
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<tutorialSteps.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - 教程步骤视图
    
    private func tutorialStepView(_ step: TutorialStep) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 图标
                Image(systemName: step.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // 标题和描述
                VStack(spacing: 12) {
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 具体内容
                step.content.view
                    .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - 导航按钮
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("上一步") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if currentStep < tutorialSteps.count - 1 {
                Button("下一步") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            } else {
                Button("开始使用") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - 教程步骤模型

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let content: TutorialContent
}

enum TutorialContent {
    case welcome
    case shortcut
    case backTap
    case automation
    case usage
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .welcome:
            welcomeContent
        case .shortcut:
            shortcutContent
        case .backTap:
            backTapContent
        case .automation:
            automationContent
        case .usage:
            usageContent
        }
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            Image("auto-ocr-demo") // 需要添加演示图片
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                Text("✨ 智能识别账单信息")
                Text("🚀 自动创建支出记录")
                Text("📊 提高记账效率")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private var shortcutContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("1")
                                .foregroundColor(.white)
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                    Text("点击\"启动自动识别\"按钮")
                    Spacer()
                }
                
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("2")
                                .foregroundColor(.white)
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                    Text("系统自动创建快捷指令")
                    Spacer()
                }
                
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("3")
                                .foregroundColor(.white)
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                    Text("授权快捷指令权限")
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text("💡 快捷指令用于在后台自动截图，是实现自动识别的关键组件")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal)
        }
    }
    
    private var backTapContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("设置 → 辅助功能 → 触控 → 背面轻点")
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("轻点两下")
                            .font(.caption)
                        Text("(可选)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("轻点三下")
                            .font(.caption)
                        Text("(推荐)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Text("⚠️ 确保选择\"轻点三下\"并设置为运行ExpenseTracker快捷指令")
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
        }
    }
    
    private var automationContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                automationLevelCard("完全自动", "bolt.fill", "无需确认，直接创建", .green)
                automationLevelCard("智能自动", "brain.head.profile", "高置信度自动，低置信度确认", .blue)
                automationLevelCard("手动确认", "hand.raised.fill", "总是需要用户确认", .orange)
            }
            
            Text("💡 推荐使用\"智能自动\"模式，平衡效率和准确性")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal)
        }
    }
    
    private func automationLevelCard(_ title: String, _ icon: String, _ description: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var usageContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                usageStepCard("1", "轻敲手机背面3次", "hand.tap", .blue)
                usageStepCard("2", "自动截图识别", "camera.viewfinder", .green)
                usageStepCard("3", "智能分析账单", "brain.head.profile", .purple)
                usageStepCard("4", "创建支出记录", "checkmark.circle", .orange)
            }
            
            Text("🎉 现在您可以开始享受自动记账的便利了！")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private func usageStepCard(_ step: String, _ title: String, _ icon: String, _ color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(step)
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                )
            
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    AutoOCRTutorialView()
} 