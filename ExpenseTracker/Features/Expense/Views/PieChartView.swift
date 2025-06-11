import SwiftUI

// MARK: - 饼图数据模型
struct PieChartData: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let value: Double
    let color: Color
    let percentage: String
    
    init(category: ExpenseCategory, value: Double, total: Double) {
        self.category = category
        self.value = value
        self.color = category.color
        let percentageValue = total > 0 ? (value / total * 100) : 0
        self.percentage = String(format: "%.1f%%", percentageValue)
    }
}

// MARK: - 主饼图视图
struct PieChartView: View {
    let data: [PieChartData]
    let total: Double
    @State private var animationProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // 图表标题
            Text("支出分类占比")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 饼图区域
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let radius = size / 2 - 20
                
                ZStack {
                    // 饼图片段
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        PieSlice(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            progress: animationProgress
                        )
                        .fill(item.color)
                        .overlay(
                            // 百分比标签（仅在片段足够大时显示）
                            Group {
                                if item.value / total > 0.05 { // 只有超过5%才显示标签
                                    Text(item.percentage)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .position(labelPosition(for: index, radius: radius, size: size))
                                }
                            }
                            .opacity(animationProgress)
                        )
                    }
                    
                    // 中心总金额显示
                    VStack(spacing: 4) {
                        Text("总支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatAmount(total))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .opacity(animationProgress)
                }
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: 250)
            
            // 图例区域
            VStack(alignment: .leading, spacing: 8) {
                Text("分类详情")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(data) { item in
                        ChartLegendItem(data: item)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - 计算起始角度
    private func startAngle(for index: Int) -> Angle {
        let previousTotal = data.prefix(index).reduce(0) { $0 + $1.value }
        return .degrees(previousTotal / total * 360 - 90)
    }
    
    // MARK: - 计算结束角度
    private func endAngle(for index: Int) -> Angle {
        let currentTotal = data.prefix(index + 1).reduce(0) { $0 + $1.value }
        return .degrees(currentTotal / total * 360 - 90)
    }
    
    // MARK: - 计算标签位置
    private func labelPosition(for index: Int, radius: Double, size: Double) -> CGPoint {
        let midAngle = (startAngle(for: index).degrees + endAngle(for: index).degrees) / 2
        let labelRadius = radius * 0.7
        let radians = midAngle * .pi / 180
        let x = size / 2 + cos(radians) * labelRadius
        let y = size / 2 + sin(radians) * labelRadius
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - 格式化金额
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
}

// MARK: - 饼图片段形状
struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let progress: Double
    
    var animatableData: Double {
        get { progress }
        set { }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        let actualEndAngle = Angle.degrees(
            startAngle.degrees + (endAngle.degrees - startAngle.degrees) * progress
        )
        
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: actualEndAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 图例项组件
struct ChartLegendItem: View {
    let data: PieChartData
    
    var body: some View {
        HStack(spacing: 8) {
            // 颜色指示器
            Circle()
                .fill(data.color)
                .frame(width: 12, height: 12)
            
            // 分类信息
            VStack(alignment: .leading, spacing: 2) {
                Text(data.category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(formatAmount(data.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(data.percentage)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(data.color)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
}

// MARK: - 支出分类饼图容器视图
struct ExpenseCategoryPieChartView: View {
    let categoryStats: [CategoryStat]
    
    var body: some View {
        let total = categoryStats.reduce(0) { $0 + $1.total }
        
        if categoryStats.isEmpty || total == 0 {
            EmptyChartView()
        } else {
            let chartData = categoryStats.map { stat in
                PieChartData(
                    category: stat.id,
                    value: stat.total,
                    total: total
                )
            }
            
            PieChartView(data: chartData, total: total)
        }
    }
}

// MARK: - 空状态图表视图
struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无统计数据")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("添加一些支出记录后即可查看分类统计图表")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding()
    }
}

// MARK: - 支出统计仪表板视图
struct ExpenseStatsDashboardView: View {
    let stats: ExpenseStats
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 总体统计卡片
                TotalStatsCard(stats: stats.totalStats)
                
                // 分类饼图
                if !stats.categoryStats.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ExpenseCategoryPieChartView(categoryStats: stats.categoryStats)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                
                // 分类排行榜
                if !stats.categoryStats.isEmpty {
                    CategoryRankingView(categoryStats: stats.categoryStats)
                }
            }
            .padding()
        }
    }
}

// MARK: - 总体统计卡片
struct TotalStatsCard: View {
    let stats: TotalStat
    
    var body: some View {
        VStack(spacing: 16) {
            Text("支出总览")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatItem(title: "总支出", value: stats.formattedTotalAmount, color: .red)
                StatItem(title: "总笔数", value: "\(stats.totalCount)", color: .blue)
                StatItem(title: "平均金额", value: stats.formattedAvgAmount, color: .green)
                StatItem(title: "最大支出", value: stats.formattedMaxAmount, color: .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - 统计项
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 分类排行榜视图
struct CategoryRankingView: View {
    let categoryStats: [CategoryStat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("支出排行")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(Array(categoryStats.enumerated()), id: \.offset) { index, stat in
                    CategoryRankItem(
                        rank: index + 1,
                        stat: stat,
                        maxValue: categoryStats.first?.total ?? 1
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 分类排行项
struct CategoryRankItem: View {
    let rank: Int
    let stat: CategoryStat
    let maxValue: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(rankColor)
                .clipShape(Circle())
            
            // 分类图标
            Image(systemName: stat.id.iconName)
                .font(.system(size: 16))
                .foregroundColor(stat.id.color)
                .frame(width: 24)
            
            // 分类信息
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.id.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(stat.count) 笔 · 平均 \(stat.formattedAvgAmount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额和进度条
            VStack(alignment: .trailing, spacing: 4) {
                Text(stat.formattedTotal)
                    .font(.body)
                    .fontWeight(.semibold)
                
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(stat.id.color)
                            .frame(width: geometry.size.width * (stat.total / maxValue), height: 4)
                    }
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

// MARK: - 预览
#Preview("饼图视图") {
    let sampleData = [
        PieChartData(category: .food, value: 1200, total: 4100),
        PieChartData(category: .transport, value: 800, total: 4100),
        PieChartData(category: .entertainment, value: 600, total: 4100),
        PieChartData(category: .shopping, value: 1500, total: 4100)
    ]
    
    PieChartView(data: sampleData, total: 4100)  // ✅ 添加了 data: 参数
        .padding()
}

#Preview("分类饼图") {
    let sampleStats = [
        CategoryStat(id: .food, total: 1200, count: 15, avgAmount: 80),
        CategoryStat(id: .transport, total: 800, count: 20, avgAmount: 40),
        CategoryStat(id: .entertainment, total: 600, count: 8, avgAmount: 75),
        CategoryStat(id: .shopping, total: 1500, count: 12, avgAmount: 125)
    ]
    
    ExpenseCategoryPieChartView(categoryStats: sampleStats)
        .padding()
}

#Preview("空状态") {
    EmptyChartView()
}
