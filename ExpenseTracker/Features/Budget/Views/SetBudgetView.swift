import SwiftUI

/**
 * 设置预算视图
 * 用于设置或修改月度预算金额
 */
struct SetBudgetView: View {
    // MARK: - 属性
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    // MARK: - 私有状态
    @State private var showConfirmation = false
    
    // MARK: - 主体视图
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 当前预算信息（如果有）
                        if viewModel.hasBudget {
                            currentBudgetSection
                        }
                        
                        // 输入区域
                        inputSection
                        
                        // 预算建议
                        suggestionSection
                        
                        // 快速金额选择
                        quickAmountSelection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(viewModel.hasBudget ? "修改预算" : "设置预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if viewModel.isBudgetInputValid {
                            showConfirmation = true
                        }
                    }
                    .disabled(!viewModel.isBudgetInputValid || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
        .alert("确认设置预算", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认") {
                viewModel.setBudget()
            }
        } message: {
            if let amount = Double(viewModel.budgetInput) {
                Text("确认设置月度预算为 \(viewModel.formatCurrency(amount)) 吗？")
            }
        }
        .overlay {
            if viewModel.isLoading {
                BudgetLoadingOverlay()
            }
        }
    }
    
    // MARK: - 头部信息
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 图标
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            // 标题和描述
            VStack(spacing: 6) {
                Text(viewModel.hasBudget ? "修改月度预算" : "设置月度预算")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.monthDisplayString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 当前预算信息
    private var currentBudgetSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("当前预算")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预算金额")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formattedBudgetAmount)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("已使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.usagePercentageString)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.statusColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - 输入区域
    private var inputSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("预算金额")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 金额输入框
                HStack {
                    Text("¥")
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $viewModel.budgetInput)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.isBudgetInputValid ? Color.blue : Color(.systemGray4),
                            lineWidth: 2
                        )
                )
                
                // 输入验证提示
                if !viewModel.budgetInputErrorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(viewModel.budgetInputErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - 预算建议
    private var suggestionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Text("预算建议")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                BudgetSuggestionRow(
                    title: "保守型",
                    description: "月收入的30-40%",
                    icon: "shield.fill",
                    color: .green
                )
                
                BudgetSuggestionRow(
                    title: "平衡型",
                    description: "月收入的50-60%",
                    icon: "scale.3d",
                    color: .blue
                )
                
                BudgetSuggestionRow(
                    title: "积极型",
                    description: "月收入的70-80%",
                    icon: "flame.fill",
                    color: .orange
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.1))
            )
        }
    }
    
    // MARK: - 快速金额选择
    private var quickAmountSelection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("快速选择")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickAmountButton(amount: 1000, viewModel: viewModel)
                QuickAmountButton(amount: 2000, viewModel: viewModel)
                QuickAmountButton(amount: 3000, viewModel: viewModel)
                QuickAmountButton(amount: 5000, viewModel: viewModel)
                QuickAmountButton(amount: 8000, viewModel: viewModel)
                QuickAmountButton(amount: 10000, viewModel: viewModel)
            }
        }
    }
}

// MARK: - 预算建议行组件
struct BudgetSuggestionRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 快速金额按钮组件
struct QuickAmountButton: View {
    let amount: Double
    @ObservedObject var viewModel: BudgetViewModel
    
    var body: some View {
        Button(action: {
            viewModel.budgetInput = String(Int(amount))
        }) {
            VStack(spacing: 4) {
                Text("¥\(Int(amount))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if amount >= 10000 {
                    Text("\(Int(amount/10000))万")
                        .font(.caption)
                        .opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预算加载覆盖层组件
struct BudgetLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("保存中...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

// MARK: - 预览
#Preview {
    SetBudgetView(viewModel: BudgetViewModel())
}
