import SwiftUI

struct AutoRecognitionView: View {
    @StateObject private var viewModel = AutoRecognitionViewModel()
    @State private var showingResultView = false
    @State private var showingAddExpenseView = false
    @State private var showingSettingsView = false
    @State private var showingTestView = false
    @State private var recognizedExpenseData: (amount: Double, description: String, category: String)?
    
    var body: some View {
        ZStack {
            // 主内容区域
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击任意位置取消识别
                    if viewModel.canCancel {
                        viewModel.cancelRecognition()
                    }
                }
            
            // 浮动状态指示器和控制按钮
            VStack {
                HStack {
                    // 设置和测试按钮
                    VStack(spacing: 8) {
                        Button(action: {
                            showingSettingsView = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.8))
                                .clipShape(Circle())
                        }
                        
                        if viewModel.isTestMode {
                            Button(action: {
                                showingTestView = true
                            }) {
                                Image(systemName: "testtube.2")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.orange.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    FloatingStatusIndicator(
                        state: viewModel.state,
                        isEnabled: viewModel.isEnabled
                    )
                    .padding(.trailing)
                }
                .padding(.top, 60) // 避免与状态栏重叠
                
                Spacer()
            }
            
            // 识别进度覆盖层
            if shouldShowProgressView {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if viewModel.canCancel {
                            viewModel.cancelRecognition()
                        }
                    }
                
                RecognitionProgressView(
                    state: viewModel.state,
                    progress: viewModel.progress,
                    progressMessage: viewModel.progressMessage,
                    onCancel: {
                        viewModel.cancelRecognition()
                    }
                )
            }
        }
        .sheet(isPresented: $showingResultView) {
            if let result = viewModel.recognitionResult {
                RecognitionResultView(
                    result: result,
                    onConfirm: { editedResult in
                        handleConfirmedResult(editedResult)
                    },
                    onCancel: {
                        showingResultView = false
                        viewModel.confirmResult()
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddExpenseView) {
            if let expenseData = recognizedExpenseData {
                AutoFilledAddExpenseView(
                    amount: expenseData.amount,
                    description: expenseData.description,
                    category: expenseData.category,
                    onDismiss: {
                        showingAddExpenseView = false
                        recognizedExpenseData = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettingsView) {
            AutoRecognitionSettingsView()
        }
        .sheet(isPresented: $showingTestView) {
            AutoRecognitionTestView()
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .success(let result) = newState {
                viewModel.recognitionResult = result
                showingResultView = true
            }
        }
        .onAppear {
            // 视图出现时确保服务正常运行
            if viewModel.isEnabled {
                // 可以添加一些初始化逻辑
            }
        }
    }
    
    // MARK: - 计算属性
    private var shouldShowProgressView: Bool {
        switch viewModel.state {
        case .waitingForConfirmation, .capturingScreen, .recognizing, .parsing, .failed(_), .cancelled:
            return true
        default:
            return false
        }
    }
    
    // MARK: - 私有方法
    private func handleConfirmedResult(_ result: RecognitionResult) {
        showingResultView = false
        
        // 准备支出数据
        let amount = result.totalAmount
        let description = result.bestDescription
        let category = result.suggestedCategory.rawValue
        
        recognizedExpenseData = (amount: amount, description: description, category: category)
        
        // 显示预填充的添加支出界面
        showingAddExpenseView = true
        
        // 确认结果
        viewModel.confirmResult()
    }
    

}

// MARK: - 预填充的添加支出视图
struct AutoFilledAddExpenseView: View {
    let amount: Double
    let description: String
    let category: String
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = AddExpenseViewModel()
    @State private var showingSuccessAlert = false
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 识别来源提示
                    recognitionSourceBanner
                    
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
                        onDismiss()
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
                Button("完成") {
                    onDismiss()
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
        .onAppear {
            // 预填充识别的数据
            viewModel.amount = String(format: "%.2f", amount)
            viewModel.description = description
            viewModel.selectedCategory = ExpenseCategory(rawValue: category) ?? .other
        }
        .onReceive(viewModel.$isSuccess) { isSuccess in
            if isSuccess {
                showingSuccessAlert = true
            }
        }
    }
    
    // MARK: - 识别来源横幅
    private var recognitionSourceBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("自动识别结果")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("以下信息已自动填充，请确认后保存")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 预览
#if DEBUG
struct AutoRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        AutoRecognitionView()
            .previewDisplayName("自动识别界面")
    }
}

struct AutoFilledAddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AutoFilledAddExpenseView(
            amount: 25.80,
            description: "星巴克咖啡",
            category: "food",
            onDismiss: {}
        )
        .previewDisplayName("预填充添加支出")
    }
}
#endif 