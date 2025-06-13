import SwiftUI

/**
 * 自动识别测试界面 - Phase 4
 * 提供测试功能的用户界面
 */
struct AutoRecognitionTestView: View {
    @StateObject private var testService = AutoRecognitionTestService.shared
    @State private var showTestReport = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 测试状态卡片
                    testStatusCard
                    
                    // 测试控制按钮
                    testControlButtons
                    
                    // 测试进度
                    if testService.testStatus == .running {
                        testProgressView
                    }
                    
                    // 测试结果列表
                    if !testService.testResults.isEmpty {
                        testResultsList
                    }
                    
                    // 性能指标
                    if let metrics = testService.performanceMetrics {
                        performanceMetricsView(metrics)
                    }
                }
                .padding()
            }
            .navigationTitle("自动识别测试")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTestReport) {
                TestReportView(report: testService.getTestReport())
            }
        }
    }
    
    // MARK: - 测试状态卡片
    
    private var testStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: testStatusIcon)
                    .foregroundColor(testStatusColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("测试状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(testStatusText)
                        .font(.headline)
                        .foregroundColor(testStatusColor)
                }
                
                Spacer()
                
                if testService.testStatus == .running {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if testService.testStatus == .completed {
                let report = testService.getTestReport()
                HStack {
                    VStack {
                        Text("\(report.totalTests)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("总测试")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(report.passedTests)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("通过")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(report.failedTests)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("失败")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(String(format: "%.1f%%", report.successRate * 100))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("成功率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 测试控制按钮
    
    private var testControlButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await testService.runFullTestSuite()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("运行完整测试套件")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(testService.testStatus == .running ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(testService.testStatus == .running)
            
            HStack(spacing: 12) {
                Button("查看报告") {
                    showTestReport = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .disabled(testService.testResults.isEmpty)
                
                Button("清除结果") {
                    clearTestResults()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .disabled(testService.testResults.isEmpty)
            }
        }
    }
    
    // MARK: - 测试进度视图
    
    private var testProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("测试进度")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.0f%%", testService.testProgress * 100))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: testService.testProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 测试结果列表
    
    private var testResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试结果")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(testService.testResults.indices, id: \.self) { index in
                    TestResultRow(result: testService.testResults[index])
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 性能指标视图
    
    private func performanceMetricsView(_ metrics: PerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能指标")
                .font(.headline)
            
            VStack(spacing: 8) {
                MetricRow(
                    title: "平均CPU使用率",
                    value: "\(String(format: "%.1f%%", metrics.averageCPUUsage))",
                    icon: "cpu"
                )
                
                MetricRow(
                    title: "峰值内存使用",
                    value: "\(String(format: "%.1fMB", metrics.peakMemoryUsage))",
                    icon: "memorychip"
                )
                
                MetricRow(
                    title: "平均响应时间",
                    value: "\(String(format: "%.2fs", metrics.averageResponseTime))",
                    icon: "clock"
                )
                
                MetricRow(
                    title: "总操作数",
                    value: "\(metrics.totalOperations)",
                    icon: "number"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 计算属性
    
    private var testStatusText: String {
        switch testService.testStatus {
        case .idle:
            return "准备就绪"
        case .running:
            return "测试进行中"
        case .completed:
            return "测试完成"
        case .failed:
            return "测试失败"
        }
    }
    
    private var testStatusIcon: String {
        switch testService.testStatus {
        case .idle:
            return "circle"
        case .running:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        }
    }
    
    private var testStatusColor: Color {
        switch testService.testStatus {
        case .idle:
            return .gray
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    // MARK: - 私有方法
    
    private func clearTestResults() {
        // 这里应该调用testService的清除方法
        // 暂时使用反射或其他方式清除结果
    }
}

// MARK: - 测试结果行视图

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testCase.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.testCase.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let errorMessage = result.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.2fs", result.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let metrics = result.metrics {
                    Text("\(String(format: "%.1f%%", metrics.accuracy * 100))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .passed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        }
    }
}

// MARK: - 指标行视图

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 测试报告视图

struct TestReportView: View {
    let report: TestReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 总体统计
                    overallStatsView
                    
                    // 详细结果
                    detailedResultsView
                    
                    // 性能指标
                    if let metrics = report.performanceMetrics {
                        performanceSection(metrics)
                    }
                }
                .padding()
            }
            .navigationTitle("测试报告")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("完成") { dismiss() })
        }
    }
    
    private var overallStatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总体统计")
                .font(.headline)
            
            HStack {
                StatCard(title: "总测试数", value: "\(report.totalTests)", color: .blue)
                StatCard(title: "通过", value: "\(report.passedTests)", color: .green)
                StatCard(title: "失败", value: "\(report.failedTests)", color: .red)
                StatCard(title: "成功率", value: "\(String(format: "%.1f%%", report.successRate * 100))", color: .orange)
            }
            
            HStack {
                Text("总耗时:")
                    .font(.subheadline)
                Spacer()
                Text("\(String(format: "%.2f秒", report.totalDuration))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var detailedResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细结果")
                .font(.headline)
            
            ForEach(report.testResults.indices, id: \.self) { index in
                TestResultRow(result: report.testResults[index])
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func performanceSection(_ metrics: PerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能指标")
                .font(.headline)
            
            VStack(spacing: 8) {
                MetricRow(title: "平均CPU使用率", value: "\(String(format: "%.1f%%", metrics.averageCPUUsage))", icon: "cpu")
                MetricRow(title: "峰值内存使用", value: "\(String(format: "%.1fMB", metrics.peakMemoryUsage))", icon: "memorychip")
                MetricRow(title: "平均响应时间", value: "\(String(format: "%.2fs", metrics.averageResponseTime))", icon: "clock")
                MetricRow(title: "总操作数", value: "\(metrics.totalOperations)", icon: "number")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 预览

struct AutoRecognitionTestView_Previews: PreviewProvider {
    static var previews: some View {
        AutoRecognitionTestView()
    }
} 