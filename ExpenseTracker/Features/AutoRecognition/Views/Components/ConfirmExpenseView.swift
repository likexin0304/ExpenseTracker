import SwiftUI

/// 确认支出数据视图
struct ConfirmExpenseView: View {
    let expenseData: AutoExpenseData
    let onConfirm: (ExpenseCorrections) -> Void
    let onCancel: () -> Void
    
    @State private var amount: Double
    @State private var merchant: String
    @State private var category: String
    @State private var date: Date
    @State private var paymentMethod: String
    @State private var notes: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(expenseData: AutoExpenseData, onConfirm: @escaping (ExpenseCorrections) -> Void, onCancel: @escaping () -> Void) {
        self.expenseData = expenseData
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        // 初始化编辑状态
        _amount = State(initialValue: expenseData.amount ?? 0)
        _merchant = State(initialValue: expenseData.merchant ?? "")
        _category = State(initialValue: expenseData.category ?? "其他")
        _paymentMethod = State(initialValue: expenseData.paymentMethod ?? "其他")
        _notes = State(initialValue: expenseData.notes ?? "")
        
        // 解析日期
        if let dateString = expenseData.date {
            let formatter = ISO8601DateFormatter()
            _date = State(initialValue: formatter.date(from: dateString) ?? Date())
        } else {
            _date = State(initialValue: Date())
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 置信度提示
                confidenceSection
                
                // 金额
                Section(header: Text("金额")) {
                    HStack {
                        Text("¥")
                            .foregroundColor(.secondary)
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .bold()
                    }
                }
                
                // 基本信息
                Section(header: Text("基本信息")) {
                    HStack {
                        Text("商户")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        TextField("请输入商户名称", text: $merchant)
                    }
                    
                    HStack {
                        Text("类别")
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Picker("", selection: $category) {
                            ForEach(expenseCategories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                
                // 支付方式
                Section(header: Text("支付方式")) {
                    Picker("支付方式", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 备注
                Section(header: Text("备注（可选）")) {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
                
                // 原始文本
                if !expenseData.rawText.isEmpty {
                    Section(header: Text("原始识别文本")) {
                        Text(expenseData.rawText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("确认支出信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        confirmExpense()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    // MARK: - 置信度提示
    private var confidenceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: confidenceIcon)
                        .foregroundColor(confidenceColor)
                    Text("识别置信度：\(confidenceText)")
                        .font(.subheadline)
                        .foregroundColor(confidenceColor)
                    Spacer()
                }
                
                Text("请仔细检查识别结果，确认无误后再提交")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 计算属性
    
    private var confidenceText: String {
        String(format: "%.0f%%", expenseData.confidence * 100)
    }
    
    private var confidenceColor: Color {
        if expenseData.confidence >= 0.8 {
            return .green
        } else if expenseData.confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceIcon: String {
        if expenseData.confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if expenseData.confidence >= 0.5 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var isValid: Bool {
        amount > 0 && !merchant.isEmpty
    }
    
    private let expenseCategories = [
        "餐饮", "交通", "购物", "娱乐", "医疗", 
        "教育", "住房", "通讯", "服装", "其他"
    ]
    
    private let paymentMethods = [
        "支付宝", "微信", "现金", "银行卡", "其他"
    ]
    
    // MARK: - 方法
    
    private func confirmExpense() {
        // 构建修正数据
        // ✅ 将字符串转换为枚举类型
        let corrections = ExpenseCorrections(
            amount: amount,
            category: ExpenseCategory(rawValue: category),
            description: merchant,
            date: date,
            location: nil,
            paymentMethod: PaymentMethod(rawValue: paymentMethod),
            tags: notes.isEmpty ? nil : [notes]
        )
        
        onConfirm(corrections)
        dismiss()
    }
}

// MARK: - 预览
#Preview {
    ConfirmExpenseView(
        expenseData: AutoExpenseData(
            amount: 25.80,
            merchant: "麦当劳",
            date: "2025-01-17",
            category: "餐饮",
            paymentMethod: "支付宝",
            notes: "午餐",
            confidence: 0.65,
            rawText: "麦当劳 25.80元 支付宝"
        ),
        onConfirm: { _ in
            print("确认")
        },
        onCancel: {
            print("取消")
        }
    )
}

