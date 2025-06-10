import SwiftUI

/**
 * 快速操作卡片组件
 * 用于首页快速操作区域的按钮卡片
 */
struct QuickActionCard: View {
    // MARK: - 属性
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    // MARK: - 状态
    @State private var isPressed = false
    
    // MARK: - 主体视图
    var body: some View {
        Button(action: {
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            VStack(spacing: 12) {
                // 图标区域
                iconSection
                
                // 文本区域
                textSection
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(16)
            .background(cardBackground)
            .overlay(cardBorder)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // MARK: - 图标区域
    private var iconSection: some View {
        ZStack {
            // 背景圆圈
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 50, height: 50)
            
            // 图标
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    // MARK: - 文本区域
    private var textSection: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.systemBackground)
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 2
            )
    }
    
    // MARK: - 卡片边框
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                color.opacity(0.2),
                lineWidth: 1
            )
    }
}

/**
 * 扩展版快速操作卡片
 * 包含更多信息和自定义布局
 */
struct ExtendedQuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String?
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // 左侧图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                // 中间文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 右侧数值（如果有）
                if let value = value {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(value)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.systemBackground)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

/**
 * 统计类型的快速操作卡片
 * 专门用于显示数据统计
 */
struct StatisticActionCard: View {
    let icon: String
    let title: String
    let value: String
    let trend: String?
    let trendDirection: TrendDirection
    let color: Color
    let action: () -> Void
    
    enum TrendDirection {
        case up, down, neutral
        
        var color: Color {
            switch self {
            case .up:
                return .systemGreen
            case .down:
                return .systemRed
            case .neutral:
                return .systemGray
            }
        }
        
        var icon: String {
            switch self {
            case .up:
                return "arrow.up"
            case .down:
                return "arrow.down"
            case .neutral:
                return "minus"
            }
        }
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：图标和趋势
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trendDirection.icon)
                                .font(.caption)
                            
                            Text(trend)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(trendDirection.color)
                    }
                }
                
                // 主要数值
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 标题
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.systemBackground)
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 4,
                        x: 0,
                        y: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.systemGray5, lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - 预览
struct QuickActionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 基础快速操作卡片
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "添加支出",
                    subtitle: "记录新的消费",
                    color: .systemBlue
                ) {
                    print("添加支出")
                }
                
                QuickActionCard(
                    icon: "clock.fill",
                    title: "支出历史",
                    subtitle: "查看消费记录",
                    color: .systemGreen
                ) {
                    print("查看历史")
                }
            }
            
            // 扩展版卡片
            ExtendedQuickActionCard(
                icon: "chart.bar.fill",
                title: "月度报告",
                subtitle: "查看详细的支出分析和趋势",
                value: "¥2,350",
                color: .systemPurple
            ) {
                print("查看报告")
            }
            
            // 统计类卡片
            HStack(spacing: 12) {
                StatisticActionCard(
                    icon: "creditcard.fill",
                    title: "本月支出",
                    value: "¥2,350",
                    trend: "+15%",
                    trendDirection: .up,
                    color: .systemBlue
                ) {
                    print("查看支出")
                }
                
                StatisticActionCard(
                    icon: "banknote.fill",
                    title: "剩余预算",
                    value: "¥1,650",
                    trend: "-8%",
                    trendDirection: .down,
                    color: .systemGreen
                ) {
                    print("查看预算")
                }
            }
        }
        .padding()
    }
}
