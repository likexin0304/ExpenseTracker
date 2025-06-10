import SwiftUI

/**
 * 预算进度圆环组件
 * 显示预算使用情况的可视化圆环图表
 */
struct BudgetProgressRing: View {
    // MARK: - 属性
    let progress: Double // 进度值 0.0 - 1.0
    let isOverBudget: Bool // 是否超支
    
    // MARK: - 动画状态
    @State private var animatedProgress: Double = 0.0
    @State private var showAnimation = false
    
    // MARK: - 计算属性
    
    /// 进度角度（0-360度）
    private var progressAngle: Double {
        return min(animatedProgress * 360, 360)
    }
    
    /// 进度颜色
    private var progressColor: Color {
        if isOverBudget {
            return .systemRed
        } else if progress > 0.8 {
            return .systemOrange
        } else if progress > 0.6 {
            return .systemYellow
        } else {
            return .systemGreen
        }
    }
    
    /// 渐变色
    private var progressGradient: Gradient {
        if isOverBudget {
            return Gradient(colors: [.red, .orange])
        } else {
            return Gradient(colors: [progressColor.opacity(0.6), progressColor])
        }
    }
    
    // MARK: - 主体视图
    var body: some View {
        VStack(spacing: 20) {
            // 圆环图
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(
                        Color.systemGray5,
                        style: StrokeStyle(
                            lineWidth: 20,
                            lineCap: .round
                        )
                    )
                    .frame(width: 160, height: 160)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: min(animatedProgress, 1.0))
                    .stroke(
                        AngularGradient(
                            gradient: progressGradient,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(progressAngle - 90)
                        ),
                        style: StrokeStyle(
                            lineWidth: 20,
                            lineCap: .round
                        )
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: animatedProgress)
                
                // 中心内容
                centerContent
            }
            
            // 图例和详细信息
            legendSection
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = newValue
            }
        }
    }
    
    // MARK: - 中心内容
    private var centerContent: some View {
        VStack(spacing: 4) {
            // 百分比显示
            Text("\(Int(progress * 100))%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .scaleEffect(showAnimation ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: showAnimation)
            
            // 状态描述
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(progressColor)
                .opacity(showAnimation ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).delay(1.0), value: showAnimation)
        }
    }
    
    // MARK: - 图例区域
    private var legendSection: some View {
        HStack(spacing: 30) {
            // 已使用
            LegendItem(
                color: progressColor,
                title: "已使用",
                value: "\(Int(progress * 100))%"
            )
            
            // 剩余
            LegendItem(
                color: .systemGray4,
                title: "剩余",
                value: "\(Int(max(0, (1 - progress) * 100)))%"
            )
        }
        .opacity(showAnimation ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.5).delay(1.2), value: showAnimation)
    }
    
    // MARK: - 计算属性
    
    /// 状态文本
    private var statusText: String {
        if isOverBudget {
            return "已超支"
        } else if progress >= 1.0 {
            return "预算用完"
        } else if progress > 0.8 {
            return "接近预算"
        } else if progress > 0.6 {
            return "使用良好"
        } else {
            return "控制良好"
        }
    }
    
    // MARK: - 私有方法
    
    /// 开始动画
    private func startAnimation() {
        showAnimation = true
        
        // 延迟启动进度动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - 图例项组件
struct LegendItem: View {
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            // 颜色指示器
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            // 标题
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 数值
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 扩展动画效果
extension BudgetProgressRing {
    /**
     * 脉冲动画效果（用于特殊状态）
     */
    private var pulseEffect: some View {
        Circle()
            .stroke(progressColor.opacity(0.3), lineWidth: 1)
            .frame(width: 180, height: 180)
            .scaleEffect(showAnimation ? 1.1 : 1.0)
            .opacity(showAnimation ? 0.0 : 0.5)
            .animation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
                value: showAnimation
            )
    }
    
    /**
     * 带脉冲效果的版本（用于超支状态）
     */
    var withPulseEffect: some View {
        ZStack {
            if isOverBudget {
                pulseEffect
            }
            self
        }
    }
}

// MARK: - 预览
struct BudgetProgressRing_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // 正常状态
            BudgetProgressRing(progress: 0.65, isOverBudget: false)
            
            // 接近预算
            BudgetProgressRing(progress: 0.85, isOverBudget: false)
            
            // 超支状态
            BudgetProgressRing(progress: 1.2, isOverBudget: true)
        }
        .padding()
    }
}
