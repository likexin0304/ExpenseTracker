import SwiftUI

/**
 * 自动识别功能教程视图 - Phase 3 新增
 * 帮助用户了解如何使用自动识别功能
 */
struct AutoRecognitionTutorialView: View {
    
    @Binding var isPresented: Bool
    @State private var currentStep: Int = 0
    
    private let tutorialSteps = [
        TutorialStep(
            title: "欢迎使用智能识别",
            description: "通过AI技术自动识别账单信息，让记账变得更简单",
            icon: "sparkles",
            color: .blue
        ),
        TutorialStep(
            title: "启用功能",
            description: "在设置中开启智能识别功能，并授予屏幕录制权限",
            icon: "gear",
            color: .green
        ),
        TutorialStep(
            title: "触发识别",
            description: "在任何显示账单信息的页面，快速敲击手机背面3次",
            icon: "hand.tap",
            color: .orange
        ),
        TutorialStep(
            title: "确认信息",
            description: "系统会自动识别金额、商家等信息，您可以编辑确认后保存",
            icon: "checkmark.circle",
            color: .purple
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 进度指示器
                HStack {
                    ForEach(0..<tutorialSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? tutorialSteps[currentStep].color : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                        
                        if index < tutorialSteps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? tutorialSteps[currentStep].color : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // 教程内容
                TabView(selection: $currentStep) {
                    ForEach(0..<tutorialSteps.count, id: \.self) { index in
                        TutorialStepView(step: tutorialSteps[index])
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // 控制按钮
                HStack(spacing: 20) {
                    if currentStep > 0 {
                        Button("上一步") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(tutorialSteps[currentStep].color)
                    }
                    
                    Spacer()
                    
                    if currentStep < tutorialSteps.count - 1 {
                        Button("下一步") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(tutorialSteps[currentStep].color)
                        .cornerRadius(25)
                    } else {
                        Button("开始使用") {
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(tutorialSteps[currentStep].color)
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationTitle("使用教程")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("跳过") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

/**
 * 教程步骤视图
 */
struct TutorialStepView: View {
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: step.icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(step.color)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: step.icon)
            
            // 标题
            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            // 描述
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding()
    }
}

/**
 * 教程步骤数据模型
 */
struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

/**
 * 预览
 */
struct AutoRecognitionTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        AutoRecognitionTutorialView(isPresented: .constant(true))
    }
} 