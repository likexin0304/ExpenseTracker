import SwiftUI
import Combine

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddExpenseViewModel()
    @State private var showingSuccessAlert = false
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 金额输入区域
                    AmountInputSection(
                        amount: $viewModel.amount,
                        isAmountFocused: $isAmountFocused,
                        errorMessage: viewModel.amountInputErrorMessage
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
            .navigationTitle("添加支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        isAmountFocused = false
                        viewModel.createExpense()
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .alert("保存成功", isPresented: $showingSuccessAlert) {
                Button("继续添加") {
                    viewModel.resetForm()
                }
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text("支出记录已成功保存")
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isLoading {
                    AddExpenseLoadingOverlay()
                }
            }
        }
        .onReceive(viewModel.$isSuccess) { isSuccess in
            if isSuccess {
                showingSuccessAlert = true
            }
        }
    }
}

// MARK: - 金额输入区域
struct AmountInputSection: View {
    @Binding var amount: String
    @FocusState.Binding var isAmountFocused: Bool
    let errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出金额")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("¥")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    
                    TextField("0.00", text: $amount)
                        .font(.title)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: amount) { _, newValue in
                            // 只允许输入数字和小数点
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                amount = filtered
                            }
                        }
                }
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onTapGesture {
                    isAmountFocused = true
                }
                
                // 错误提示
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            // 快速金额选择
            QuickAmountButtons(amount: $amount)
        }
    }
}

// MARK: - 快速金额按钮
struct QuickAmountButtons: View {
    @Binding var amount: String
    
    private let quickAmounts = ["10", "20", "50", "100", "200", "500"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快速选择")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(quickAmounts, id: \.self) { quickAmount in
                    Button(action: {
                        amount = quickAmount
                    }) {
                        Text("¥\(quickAmount)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - 基本信息区域
struct BasicInfoSection: View {
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
            CategorySelectionView(selectedCategory: $selectedCategory)
            
            // 描述输入
            VStack(alignment: .leading, spacing: 8) {
                Text("描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("请输入支出描述", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // 日期和地点
            HStack(spacing: 16) {
                // 日期选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                }
                
                // 地点输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("地点 (可选)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("请输入地点", text: $location)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }
}

// MARK: - 分类选择视图
struct CategorySelectionView: View {
    @Binding var selectedCategory: ExpenseCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(ExpenseCategory.allCases) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

// MARK: - 分类按钮
struct CategoryButton: View {
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
struct PaymentMethodSection: View {
    @Binding var selectedPaymentMethod: PaymentMethod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支付方式")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    PaymentMethodButton(
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
struct PaymentMethodButton: View {
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
struct TagsSection: View {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // 标签列表
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(tag: tag) {
                                onRemoveTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
}

// MARK: - 标签芯片
struct TagChip: View {
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
struct NotesSection: View {
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
                .overlay(
                    // 占位符
                    VStack {
                        HStack {
                            if notes.isEmpty {
                                Text("添加备注...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                    .padding(.leading, 8)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                )
        }
    }
}

// MARK: - 高级选项区域
struct AdvancedOptionsSection: View {
    @Binding var isRecurring: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("高级选项")
                .font(.headline)
                .foregroundColor(.primary)
            
            Toggle("重复支出", isOn: $isRecurring)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - 添加支出专用加载覆盖层
struct AddExpenseLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)
                
                Text("保存中...")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

// MARK: - 添加支出视图模型
class AddExpenseViewModel: ObservableObject {
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
    
    private let expenseService: ExpenseServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(expenseService: ExpenseServiceProtocol = ExpenseService()) {
        self.expenseService = expenseService
    }
    
    // MARK: - 计算属性
    
    /// 金额输入错误提示
    var amountInputErrorMessage: String {
        if amount.isEmpty {
            return ""
        }
        
        guard let amountValue = Double(amount) else {
            return "请输入有效的数字"
        }
        
        if amountValue <= 0 {
            return "金额必须大于0"
        }
        
        if amountValue > 100000 {
            return "金额不能超过10万元"
        }
        
        return ""
    }
    
    /// 表单验证
    var isFormValid: Bool {
        !amount.isEmpty &&
        Double(amount) != nil &&
        Double(amount)! > 0 &&
        Double(amount)! <= 100000 &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - 方法
    
    /// 添加标签
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
    
    /// 删除标签
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    /// 重置表单
    func resetForm() {
        amount = ""
        selectedCategory = .other
        description = ""
        selectedDate = Date()
        location = ""
        selectedPaymentMethod = .cash
        isRecurring = false
        tags = []
        newTag = ""
        notes = ""
        isSuccess = false
    }
    
    /// 创建支出记录
    func createExpense() {
        guard isFormValid else {
            errorMessage = "请填写所有必填字段"
            return
        }
        
        guard let amountValue = Double(amount) else {
            errorMessage = "请输入有效的金额"
            return
        }
        
        let request = CreateExpenseRequest(
            amount: amountValue,
            category: selectedCategory.rawValue,
            description: description.trimmingCharacters(in: .whitespaces),
            date: selectedDate,
            location: location.isEmpty ? nil : location,
            paymentMethod: selectedPaymentMethod.rawValue,
            tags: tags
        )
        
        isLoading = true
        errorMessage = nil
        
        expenseService.createExpense(
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
                    print("✅ 支出记录创建成功")
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 预览
#if DEBUG
struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView()
    }
}
#endif
