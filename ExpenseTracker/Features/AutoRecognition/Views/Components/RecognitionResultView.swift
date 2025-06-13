import SwiftUI

struct RecognitionResultView: View {
    let result: RecognitionResult
    let onConfirm: (RecognitionResult) -> Void
    let onCancel: () -> Void
    
    @State private var editedResult: RecognitionResult
    @Environment(\.dismiss) private var dismiss
    
    init(result: RecognitionResult, onConfirm: @escaping (RecognitionResult) -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self._editedResult = State(initialValue: result)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 识别结果概览
                    resultOverviewSection
                    
                    // 金额选择
                    amountSelectionSection
                    
                    // 基本信息编辑
                    basicInfoSection
                    
                    // 推荐分类
                    categorySection
                    
                    // 原始文本（可折叠）
                    originalTextSection
                }
                .padding()
            }
            .navigationTitle("确认识别结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        onConfirm(editedResult)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidResult)
                }
            }
        }
    }
    
    // MARK: - 识别结果概览
    private var resultOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("识别成功")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 置信度指示器
                confidenceIndicator
            }
            
            if let merchantName = editedResult.merchantName, !merchantName.isEmpty {
                HStack {
                    Text("商家:")
                        .foregroundColor(.secondary)
                    Text(merchantName)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 置信度指示器
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Text("置信度")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(editedResult.ocrConfidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
        }
    }
    
    private var confidenceColor: Color {
        if editedResult.ocrConfidence >= 0.8 {
            return .green
        } else if editedResult.ocrConfidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - 金额选择
    private var amountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出金额")
                .font(.headline)
                .foregroundColor(.primary)
            
            if editedResult.amounts.count > 1 {
                // 多个金额选择
                multipleAmountsView
            } else {
                // 单个金额编辑
                singleAmountView
            }
        }
    }
    
    private var multipleAmountsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("检测到多个金额，请选择:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(editedResult.amounts, id: \.self) { amount in
                    Button(action: {
                        editedResult.selectedAmount = amount
                    }) {
                        HStack {
                            Text("¥\(amount, specifier: "%.2f")")
                                .fontWeight(.medium)
                            Spacer()
                            if editedResult.selectedAmount == amount {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(
                            editedResult.selectedAmount == amount ? 
                            Color.blue.opacity(0.1) : Color(.systemGray6)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 总和选项
            let totalAmount = editedResult.totalAmount
            Button(action: {
                editedResult.selectedAmount = totalAmount
            }) {
                HStack {
                    Text("总计: ¥\(totalAmount, specifier: "%.2f")")
                        .fontWeight(.medium)
                    Spacer()
                    if editedResult.selectedAmount == totalAmount {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(
                    editedResult.selectedAmount == totalAmount ? 
                    Color.blue.opacity(0.1) : Color(.systemGray6)
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var singleAmountView: some View {
        HStack {
            Text("¥")
                .font(.title2)
                .foregroundColor(.secondary)
            
            TextField("金额", value: Binding(
                get: { editedResult.selectedAmount ?? editedResult.totalAmount },
                set: { editedResult.selectedAmount = $0 }
            ), format: .number.precision(.fractionLength(2)))
                .font(.title2)
                .keyboardType(.decimalPad)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - 基本信息编辑
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 描述
            VStack(alignment: .leading, spacing: 8) {
                Text("描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("支出描述", text: Binding(
                    get: { editedResult.editedDescription ?? editedResult.bestDescription },
                    set: { editedResult.editedDescription = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // 时间
            if let detectedDate = editedResult.detectedDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("交易时间")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: Binding(
                        get: { editedResult.editedTransactionTime ?? detectedDate },
                        set: { editedResult.editedTransactionTime = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
                }
            }
            
            // 支付方式
            if let paymentMethod = editedResult.paymentMethod {
                VStack(alignment: .leading, spacing: 8) {
                    Text("支付方式")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(paymentMethod)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - 分类推荐
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐分类")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: categoryIcon(for: editedResult.suggestedCategory))
                    .foregroundColor(.blue)
                
                Text(categoryDisplayName(for: editedResult.suggestedCategory))
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("推荐")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 原始文本
    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("原始识别文本") {
                Text(editedResult.rawText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .font(.subheadline)
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - 计算属性
    private var isValidResult: Bool {
        let amount = editedResult.selectedAmount ?? editedResult.totalAmount
        let description = editedResult.editedDescription ?? editedResult.bestDescription
        return amount > 0 && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - 辅助方法
    private func categoryIcon(for category: ExpenseCategory) -> String {
        switch category {
        case .food:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "gamecontroller.fill"
        case .healthcare:
            return "cross.fill"
        case .education:
            return "book.fill"
        case .bills:
            return "doc.text.fill"
        case .travel:
            return "airplane"
        case .other:
            return "questionmark.circle"
        }
    }
    
    private func categoryDisplayName(for category: ExpenseCategory) -> String {
        switch category {
        case .food:
            return "餐饮"
        case .transport:
            return "交通"
        case .shopping:
            return "购物"
        case .entertainment:
            return "娱乐"
        case .healthcare:
            return "医疗"
        case .education:
            return "教育"
        case .bills:
            return "账单"
        case .travel:
            return "旅行"
        case .other:
            return "其他"
        }
    }
}

// MARK: - 预览
#if DEBUG
struct RecognitionResultView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResult = RecognitionResult(
            amounts: [25.80, 3.50],
            description: "星巴克咖啡",
            merchantName: "星巴克",
            detectedDate: Date(),
            paymentMethod: "微信支付",
            rawText: "星巴克\n拿铁咖啡 ¥25.80\n配送费 ¥3.50\n微信支付",
            suggestedCategory: .food,
            categoryConfidence: 0.85,
            ocrConfidence: 0.85
        )
        
        RecognitionResultView(
            result: sampleResult,
            onConfirm: { _ in },
            onCancel: { }
        )
        .previewDisplayName("识别结果确认")
    }
}
#endif 