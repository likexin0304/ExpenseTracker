import SwiftUI

/**
 * 首页视图
 * 显示预算概览、支出统计和快速操作
 */
struct HomeView: View {
    // MARK: - 状态管理
    @StateObject private var budgetViewModel = BudgetViewModel()
    @StateObject private var authService = AuthService.shared
    @State private var showingAddExpense = false
    
    // 用于标签页切换的绑定
    @Binding var selectedTab: Int
    
    // MARK: - 初始化
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    // MARK: - 主体视图
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户欢迎区域
                    userWelcomeSection
                    
                    // 预算卡片
                    budgetCard
                    
                    // 统计图表区域
                    if budgetViewModel.hasBudget {
                        statisticsSection
                    }
                    
                    // 快速操作区域
                    quickActionsSection
                    
                    // 预算建议
                    if budgetViewModel.hasBudget {
                        suggestionSection
                    }
                    
                    Spacer(minLength: 100) // 底部间距
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("记账助手")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("设置") {
                        // TODO: 跳转到设置页面
                    }
                }
            }
            .refreshable {
                budgetViewModel.refreshBudget()
            }
        }
        .onAppear {
            // 只在用户已登录时才加载预算数据
            if authService.isAuthenticated {
                budgetViewModel.loadBudgetData()
            } else {
                print("⚠️ 用户未登录，跳过预算数据加载")
            }
        }
        .alert("错误", isPresented: $budgetViewModel.showError) {
            Button("确定") {
                budgetViewModel.showError = false
            }
        } message: {
            Text(budgetViewModel.errorMessage)
        }
        .sheet(isPresented: $budgetViewModel.showSetBudgetSheet) {
            SetBudgetView(viewModel: budgetViewModel)
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(selectedTab: .constant(0), onDismiss: {
                showingAddExpense = false
            })
            .onDisappear {
                // 刷新预算数据，因为可能添加了新支出
                budgetViewModel.refreshBudget()
            }
        }
    }
    
    // MARK: - 用户欢迎区域
    private var userWelcomeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello, \(authService.currentUser?.email.components(separatedBy: "@").first ?? "用户")")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(budgetViewModel.monthDisplayString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 用户头像占位符
            Circle()
                .fill(Color.systemBlue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.systemBlue)
                )
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 预算卡片
    private var budgetCard: some View {
        VStack(spacing: 0) {
            // 卡片头部
            budgetCardHeader
            
            // 卡片内容
            if budgetViewModel.hasBudget {
                budgetCardContent
            } else {
                noBudgetContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.systemBlue.opacity(0.8),
                            Color.systemBlue
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .foregroundColor(.white)
    }
    
    // MARK: - 预算卡片头部
    private var budgetCardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("月度预算")
                    .font(.headline)
                    .fontWeight(.medium)
                
                if budgetViewModel.hasBudget {
                    Text(budgetViewModel.remainingDaysInMonth)
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            
            Spacer()
            
            Button(action: {
                budgetViewModel.showSetBudget()
            }) {
                Image(systemName: budgetViewModel.hasBudget ? "pencil" : "plus")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - 预算卡片内容（有预算）
    private var budgetCardContent: some View {
        VStack(spacing: 16) {
            // 预算金额显示
            VStack(spacing: 8) {
                Text(budgetViewModel.formattedBudgetAmount)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("预算总额")
                    .font(.subheadline)
                    .opacity(0.8)
            }
            
            // 进度条
            VStack(spacing: 8) {
                ProgressView(value: budgetViewModel.usageProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text("已花费 \(budgetViewModel.formattedExpensesAmount)")
                        .font(.caption)
                        .opacity(0.9)
                    
                    Spacer()
                    
                    Text(budgetViewModel.usagePercentageString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .opacity(0.9)
                }
            }
            
            // 剩余预算
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("剩余预算")
                        .font(.caption)
                        .opacity(0.8)
                    
                    Text(budgetViewModel.formattedRemainingBudget)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均每日可用")
                        .font(.caption)
                        .opacity(0.8)
                    
                    Text(budgetViewModel.averageDailyBudget)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - 未设置预算内容
    private var noBudgetContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .opacity(0.6)
            
            VStack(spacing: 8) {
                Text("还未设置预算")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("设置月度预算，更好地管理您的支出")
                    .font(.subheadline)
                    .opacity(0.8)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                budgetViewModel.showSetBudget()
            }) {
                Text("立即设置")
                    .font(.headline)
                    .foregroundColor(.systemBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - 统计图表区域
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("支出统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看详情") {
                    budgetViewModel.showBudgetDetails = true
                }
                .font(.subheadline)
                .foregroundColor(.systemBlue)
            }
            
            // 圆环进度图
            BudgetProgressRing(
                progress: budgetViewModel.usageProgress,
                isOverBudget: budgetViewModel.isOverBudget
            )
            .frame(height: 200)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 快速操作区域
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("快速操作")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // 添加支出按钮
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "添加支出",
                    subtitle: "记录新的消费",
                    color: .systemBlue
                ) {
                    showingAddExpense = true
                }
                
                // 查看历史按钮
                QuickActionCard(
                    icon: "clock.fill",
                    title: "支出历史",
                    subtitle: "查看消费记录",
                    color: .systemGreen
                ) {
                    selectedTab = 1 // 切换到记录页面
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 预算建议区域
    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.systemYellow)
                
                Text("智能建议")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(budgetViewModel.budgetSuggestion)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemYellow.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.systemYellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - 预览
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(selectedTab: .constant(0))
    }
}
