import SwiftUI
import Combine

struct EditExpenseView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditExpenseViewModel
    @FocusState private var isAmountFocused: Bool
    
    init(expense: Expense) {
        self.expense = expense
        self._viewModel = StateObject(wrappedValue: EditExpenseViewModel(expense: expense))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 金额输入区域
                    AmountInputSection(
                        amount: $viewModel.amount,
                        isAmountFocused: $isAmountFocused,
                        errorMessage: viewModel.amountErrorMessage
                    )
                    
                    // 基本信息区域
                    BasicInfoSection(
                        selectedCategory: $viewModel.selectedCategory,
                        description: $viewModel.description,
                        selectedDate: $viewModel.selectedDate,
                        location: $viewModel.location
                    )
                    
                    // 支付方式区域
                    PaymentMethodSection(selectedPaymentMethod: $viewModel.selectedPaymentMethod)
                    
                    // 标签区域
                    TagsSection(
                        tags: $viewModel.tags,
                        newTag: $viewModel.newTag,
                        onAddTag: viewModel.addTag,
                        onRemoveTag: viewModel.removeTag
                    )
                    
                    // 备注区域
                    NotesSection(notes: $viewModel.notes)
                    
                    // 高级选项
                    AdvancedOptionsSection(isRecurring: $viewModel.isRecurring)
                }
                .padding()
            }
            .navigationTitle("编辑支出")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.updateExpense()
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("成功", isPresented: .constant(viewModel.isSuccess)) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("支出记录已更新")
            }
            .overlay {
                if viewModel.isLoading {
                    EditLoadingOverlay()
                }
            }
        }
    }
}

// MARK: - 编辑支出视图模型
class EditExpenseViewModel: ObservableObject {
    let expense: Expense
    
    @Published var amount: String = ""
    @Published var selectedCategory: ExpenseCategory = .other
    @Published var description: String = ""
    @Published var selectedDate: Date = Date()
    @Published var location: String = ""
    @Published var selectedPaymentMethod: PaymentMethod = .cash
    @Published var isRecurring: Bool = false
    @Published var tags: [String] = []
    @Published var newTag: String = ""
    @Published var notes: String = ""
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    
    // 金额错误消息
    var amountErrorMessage: String {
        if amount.isEmpty {
            return ""
        } else if Double(amount) == nil {
            return "请输入有效的数字"
        } else if let amountValue = Double(amount), amountValue <= 0 {
            return "金额必须大于0"
        }
        return ""
    }
    
    private let expenseService: ExpenseServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(expense: Expense, expenseService: ExpenseServiceProtocol = ExpenseService()) {
        self.expense = expense
        self.expenseService = expenseService
        
        // 初始化表单数据
        self.amount = String(expense.amount)
        self.selectedCategory = ExpenseCategory(rawValue: expense.category) ?? .other
        self.description = expense.description
        self.selectedDate = expense.date
        self.location = expense.location ?? ""
        self.selectedPaymentMethod = PaymentMethod(rawValue: expense.paymentMethod) ?? .cash
        self.isRecurring = false // isRecurring字段已移除
        self.tags = expense.tags
        self.notes = "" // notes字段已移除
    }
    
    // MARK: - 表单验证
    var isFormValid: Bool {
        !amount.isEmpty &&
        Double(amount) != nil &&
        Double(amount)! > 0 &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - 添加标签
    func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmedTag.isEmpty &&
           !tags.contains(trimmedTag) &&
           tags.count < 10 &&
           trimmedTag.count <= 20 {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    // MARK: - 删除标签
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    // MARK: - 更新支出记录
    func updateExpense() {
        guard isFormValid else {
            errorMessage = "请填写所有必填字段"
            return
        }
        
        guard let amountValue = Double(amount) else {
            errorMessage = "请输入有效的金额"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        expenseService.updateExpense(
            expenseId: expense.id,
            amount: amountValue,
            category: selectedCategory.rawValue,
            description: description.trimmingCharacters(in: .whitespaces),
            date: selectedDate,
            location: location.isEmpty ? nil : location,
            paymentMethod: selectedPaymentMethod.rawValue,
            tags: tags
        )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSuccess = true
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 编辑加载覆盖层
struct EditLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("更新中...")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
}

// MARK: - UI组件 (从 AddExpenseView 复制过来)

// MARK: - 金额输入区域
struct EditAmountInputSection: View {
    @Binding var amount: String
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出金额")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("¥")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: $amount)
                    .font(.title)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .onTapGesture {
                isAmountFocused = true
            }
        }
    }
}

// MARK: - 基本信息区域
struct EditBasicInfoSection: View {
    @Binding var selectedCategory: ExpenseCategory
    @Binding var description: String
    @Binding var selectedDate: Date
    @Binding var location: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 分类选择
            VStack(alignment: .leading, spacing: 8) {
                Text("分类")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(ExpenseCategory.allCases) { category in
                        EditCategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            
            // 描述输入
            VStack(alignment: .leading, spacing: 8) {
                Text("描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("请输入支出描述", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // 日期选择
            VStack(alignment: .leading, spacing: 8) {
                Text("日期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
            }
            
            // 地点输入
            VStack(alignment: .leading, spacing: 8) {
                Text("地点 (可选)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("请输入支出地点", text: $location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

// MARK: - 分类按钮
struct EditCategoryButton: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? category.color : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 支付方式区域
struct EditPaymentMethodSection: View {
    @Binding var selectedPaymentMethod: PaymentMethod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支付方式")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(PaymentMethod.allCases) { method in
                    EditPaymentMethodButton(
                        method: method,
                        isSelected: selectedPaymentMethod == method
                    ) {
                        selectedPaymentMethod = method
                    }
                }
            }
        }
    }
}

// MARK: - 支付方式按钮
struct EditPaymentMethodButton: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: method.iconName)
                    .foregroundColor(isSelected ? .white : method.color)
                
                Text(method.displayName)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding()
            .background(isSelected ? method.color : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 标签区域
struct EditTagsSection: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    let onAddTag: () -> Void
    let onRemoveTag: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签 (可选)")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 添加标签输入
            HStack {
                TextField("添加标签", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("添加", action: onAddTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            // 标签列表
            if !tags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        EditTagChip(tag: tag) {
                            onRemoveTag(tag)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 标签芯片
struct EditTagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
    }
}

// MARK: - 备注区域
struct EditNotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注 (可选)")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - 高级选项区域
struct EditAdvancedOptionsSection: View {
    @Binding var isRecurring: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("高级选项")
                .font(.headline)
                .foregroundColor(.primary)
            
            Toggle("重复支出", isOn: $isRecurring)
        }
    }
}

#Preview {
    EditExpenseView(expense: Expense.sample())
}
