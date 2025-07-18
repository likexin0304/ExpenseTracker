import SwiftUI
import Combine

/// OCR历史记录界面
struct OCRHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ocrAPIService = OCRAPIService.shared
    @State private var records: [OCRRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRecord: OCRRecord?
    @State private var showingDetail = false
    @State private var searchText = ""
    @State private var selectedStatus: String = "all"
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: OCRRecord?
    @State private var cancellables = Set<AnyCancellable>()
    
    private let statusOptions = [
        ("all", "全部"),
        ("pending", "待确认"),
        ("confirmed", "已确认"),
        ("failed", "失败")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和筛选
                searchAndFilterSection
                
                // 记录列表
                recordsList
            }
            .navigationTitle("处理历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        loadRecords()
                    }
                }
            }
        }
        .onAppear {
            loadRecords()
        }
        .sheet(isPresented: $showingDetail) {
            if let record = selectedRecord {
                OCRRecordDetailView(record: record)
            }
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - 搜索和筛选
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索商户名称或金额", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 状态筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(statusOptions, id: \.0) { status, title in
                        Button(action: {
                            selectedStatus = status
                            loadRecords()
                        }) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedStatus == status ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedStatus == status ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 记录列表
    
    private var recordsList: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRecords.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredRecords, id: \.id) { record in
                        recordRow(record)
                            .onTapGesture {
                                selectedRecord = record
                                showingDetail = true
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无记录")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("开始使用自动记账功能后，处理历史将显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 记录行
    
    private func recordRow(_ record: OCRRecord) -> some View {
        VStack(spacing: 12) {
            // 主要信息
            HStack {
                // 状态指示器
                statusIndicator(for: record)
                
                // 记录信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // 商户信息
                        if let merchantName = record.parsedData.merchant?.name {
                            Label(merchantName, systemImage: "building.2")
                                .foregroundColor(.primary)
                        } else {
                            Label("未知商户", systemImage: "building.2")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let amount = record.parsedData.amount?.value {
                            Text("¥\(String(format: "%.2f", amount))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    HStack {
                        Text("置信度: \(Int(record.confidenceScore * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDate(record.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 识别文本预览
            if !record.originalText.isEmpty {
                HStack {
                    Text("识别文本:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.originalText.prefix(50) + (record.originalText.count > 50 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // MARK: - 状态指示器
    
    private func statusIndicator(for record: OCRRecord) -> some View {
        Circle()
            .fill(statusColor(for: record))
            .frame(width: 12, height: 12)
    }
    
    private func statusColor(for record: OCRRecord) -> Color {
        switch record.status {
        case "pending":
            return .orange
        case "confirmed":
            return .green
        case "failed":
            return .red
        default:
            return .gray
        }
    }
    
    // MARK: - 计算属性
    
    private var filteredRecords: [OCRRecord] {
        var filtered = records
        
        // 状态筛选
        if selectedStatus != "all" {
            filtered = filtered.filter { $0.status == selectedStatus }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                let merchantMatch = record.parsedData.merchant?.name.localizedCaseInsensitiveContains(searchText) ?? false
                let amountMatch = record.parsedData.amount?.value != nil ? "\(record.parsedData.amount!.value)".contains(searchText) : false
                let textMatch = record.originalText.localizedCaseInsensitiveContains(searchText)
                
                return merchantMatch || amountMatch || textMatch
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - 私有方法
    
    private func loadRecords() {
        isLoading = true
        errorMessage = nil
        
        ocrAPIService.getOCRRecords(page: 1, limit: 100)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = "加载失败: \(error.localizedDescription)"
                    }
                },
                receiveValue: { data in
                    records = data.records
                }
            )
            .store(in: &cancellables)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - OCR记录详情视图

struct OCRRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: OCRRecord
    @StateObject private var ocrAPIService = OCRAPIService.shared
    @State private var isConfirming = false
    @State private var showingConfirmation = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 状态卡片
                    statusCard
                    
                    // 解析结果
                    parsedDataSection
                    
                    // 原始文本
                    originalTextSection
                    
                    // 置信度信息
                    confidenceSection
                    
                    // 操作按钮
                    if record.status == "pending" {
                        actionButtons
                    }
                }
                .padding()
            }
            .navigationTitle("识别详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .alert("确认创建支出记录", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认") {
                confirmRecord()
            }
        } message: {
            Text("确认根据此识别结果创建支出记录吗？")
        }
    }
    
    private var statusCard: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 16, height: 16)
            
            Text(statusText)
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("置信度: \(Int(record.confidenceScore * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch record.status {
        case "pending": return .orange
        case "confirmed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch record.status {
        case "pending": return "待确认"
        case "confirmed": return "已确认"
        case "failed": return "识别失败"
        default: return "未知状态"
        }
    }
    
    private var parsedDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解析结果")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let merchantName = record.parsedData.merchant?.name {
                    dataRow("商户名称", merchantName)
                }
                
                if let amount = record.parsedData.amount?.value {
                    dataRow("金额", "¥\(String(format: "%.2f", amount))")
                }
                
                if let date = record.parsedData.date?.value {
                    dataRow("日期", date)
                }
                
                if let category = record.parsedData.category?.name {
                    dataRow("分类", category)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func dataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
    
    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("原始识别文本")
                .font(.headline)
            
            Text(record.originalText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("置信度分析")
                .font(.headline)
            
            VStack(spacing: 8) {
                confidenceBar("总体置信度", record.confidenceScore)
                
                if let merchantConfidence = record.parsedData.merchant?.confidence {
                    confidenceBar("商户识别", merchantConfidence)
                }
                
                if let amountConfidence = record.parsedData.amount?.confidence {
                    confidenceBar("金额识别", amountConfidence)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func confidenceBar(_ label: String, _ confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(confidence * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(confidenceColor(confidence))
                        .frame(width: geometry.size.width * confidence, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    if isConfirming {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    Text("确认并创建支出记录")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isConfirming)
            
            Button(action: {
                // 删除记录
                deleteRecord()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除记录")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    private func confirmRecord() {
        isConfirming = true
        
        ocrAPIService.confirmOCRRecord(recordId: record.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isConfirming = false
                    if case .failure(let error) = completion {
                        print("确认失败: \(error)")
                    } else {
                        dismiss()
                    }
                },
                receiveValue: { _ in
                    // 确认成功
                }
            )
            .store(in: &cancellables)
    }
    
    private func deleteRecord() {
        ocrAPIService.deleteOCRRecord(recordId: record.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("删除失败: \(error)")
                    } else {
                        dismiss()
                    }
                },
                receiveValue: { _ in
                    // 删除成功
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    OCRHistoryView()
} 