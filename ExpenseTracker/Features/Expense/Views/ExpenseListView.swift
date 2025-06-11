import SwiftUI

struct ExpenseListView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var showingFilters = false
    @State private var selectedExpense: Expense?
    @State private var showingExpenseDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 汇总信息卡片
                if !viewModel.expenses.isEmpty {
                    ExpenseSummaryCard(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // 筛选状态栏
                if viewModel.hasActiveFilters {
                    FilterStatusBar(viewModel: viewModel)
                        .padding(.horizontal)
                }
                
                // 主要内容区域
                Group {
                    if viewModel.expenses.isEmpty && !viewModel.isLoading {
                        ExpenseEmptyStateView {
                            showingAddExpense = true
                        }
                    } else {
                        ExpenseList(viewModel: viewModel, selectedExpense: $selectedExpense)
                    }
                }
            }
            .navigationTitle("支出记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(viewModel.hasActiveFilters ? .blue : .primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                viewModel.loadExpenses(refresh: true)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView()
                .onDisappear {
                    viewModel.loadExpenses(refresh: true)
                }
        }
        .sheet(isPresented: $showingFilters) {
            ExpenseFilterView(viewModel: viewModel)
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
        .alert("错误", isPresented: $viewModel.showingError) {
            Button("确定") {
                viewModel.errorMessage = nil
                viewModel.showingError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            if viewModel.expenses.isEmpty {
                viewModel.loadExpenses(refresh: true)
            }
        }
    }
}

// MARK: - 支出汇总卡片
struct ExpenseSummaryCard: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formattedTotalAmount)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("笔数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.expenseCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(averageAmount)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            // 添加分类统计图表
            if !viewModel.expenses.isEmpty {
                CategoryStatsBar(viewModel: viewModel)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var averageAmount: String {
        guard viewModel.expenseCount > 0 else { return "¥0.00" }
        let average = viewModel.totalAmount / Double(viewModel.expenseCount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: average)) ?? "¥0.00"
    }
}

// MARK: - 分类统计条形图
struct CategoryStatsBar: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类统计")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(topCategories, id: \.category) { stat in
                    Rectangle()
                        .fill(stat.category.color)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                        .frame(width: CGFloat(stat.percentage) * 200)
                }
            }
            .cornerRadius(2)
            
            // 显示前3个分类
            HStack {
                ForEach(topCategories.prefix(3), id: \.category) { stat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stat.category.color)
                            .frame(width: 8, height: 8)
                        Text(stat.category.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if stat.category != topCategories.prefix(3).last?.category {
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var topCategories: [(category: ExpenseCategory, percentage: Double)] {
        let total = viewModel.totalAmount
        guard total > 0 else { return [] }
        
        let categoryTotals = ExpenseCategory.allCases.compactMap { category -> (category: ExpenseCategory, percentage: Double)? in
            let categoryTotal = viewModel.expenses
                .filter { $0.category == category.rawValue }
                .reduce(0) { $0 + $1.amount }
            
            guard categoryTotal > 0 else { return nil }
            return (category: category, percentage: categoryTotal / total)
        }
        
        return categoryTotals.sorted { $0.percentage > $1.percentage }
    }
}

// MARK: - 筛选状态栏
struct FilterStatusBar: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let category = viewModel.selectedCategory {
                            FilterChip(text: category.displayName, icon: category.iconName, color: category.color)
                        }
                        
                        if viewModel.startDate != nil || viewModel.endDate != nil {
                            FilterChip(text: "时间范围", icon: "calendar", color: .blue)
                        }
                        
                        if !viewModel.searchText.isEmpty {
                            FilterChip(text: "搜索: \(viewModel.searchText)", icon: "magnifyingglass", color: .purple)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                
                Button("清除", action: viewModel.clearFilters)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 筛选芯片
struct FilterChip: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - 支出列表
struct ExpenseList: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @Binding var selectedExpense: Expense?
    
    var body: some View {
        List {
            ForEach(groupedExpenses, id: \.date) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        ExpenseRowView(expense: expense)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedExpense = expense
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("删除", role: .destructive) {
                                    viewModel.deleteExpense(expense)
                                }
                                
                                Button("编辑") {
                                    // TODO: 编辑功能
                                }
                                .tint(.blue)
                            }
                            .onAppear {
                                // 分页加载
                                if expense.id == viewModel.expenses.last?.id {
                                    viewModel.loadMoreExpenses()
                                }
                            }
                    }
                } header: {
                    Text(group.date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
            
            // 加载更多指示器
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载更多...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .overlay {
            if viewModel.isLoading && viewModel.expenses.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
    }
    
    private var groupedExpenses: [(date: String, expenses: [Expense])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        let grouped = Dictionary(grouping: viewModel.expenses) { expense -> String in
            if Calendar.current.isDateInToday(expense.date) {
                return "今天"
            } else if Calendar.current.isDateInYesterday(expense.date) {
                return "昨天"
            } else if Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .weekOfYear) {
                formatter.dateFormat = "EEEE"
                return formatter.string(from: expense.date)
            } else {
                formatter.dateFormat = "MM月dd日"
                return formatter.string(from: expense.date)
            }
        }
        
        return grouped.sorted { lhs, rhs in
            // 自定义排序逻辑
            let order = ["今天", "昨天"]
            if let lhsIndex = order.firstIndex(of: lhs.key),
               let rhsIndex = order.firstIndex(of: rhs.key) {
                return lhsIndex < rhsIndex
            } else if order.contains(lhs.key) {
                return true
            } else if order.contains(rhs.key) {
                return false
            } else {
                return lhs.key > rhs.key
            }
        }.map { (date: $0.key, expenses: $0.value) }
    }
}

// MARK: - 支出行视图
struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            ZStack {
                let categoryEnum = ExpenseCategory(rawValue: expense.category) ?? .other
                Circle()
                    .fill(categoryEnum.color)
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryEnum.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // 支出信息
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    let categoryEnum = ExpenseCategory(rawValue: expense.category) ?? .other
                    Text(categoryEnum.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = expense.location, !location.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 支付方式标签
                    HStack(spacing: 2) {
                        let paymentEnum = PaymentMethod(rawValue: expense.paymentMethod) ?? .cash
                        Image(systemName: paymentEnum.iconName)
                            .font(.caption2)
                        Text(paymentEnum.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((PaymentMethod(rawValue: expense.paymentMethod) ?? .cash).color.opacity(0.1))
                    .foregroundColor((PaymentMethod(rawValue: expense.paymentMethod) ?? .cash).color)
                    .cornerRadius(4)
                }
                
                // 标签显示
                if !expense.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(expense.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 金额和时间
            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.formattedAmount)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(formatTime(expense.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 空状态视图
struct ExpenseEmptyStateView: View {
    let onAddExpense: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无支出记录")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("开始记录您的支出，更好地管理财务")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onAddExpense) {
                HStack {
                    Image(systemName: "plus")
                    Text("添加第一笔支出")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - 支出筛选视图
struct ExpenseFilterView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("分类筛选") {
                    Picker("选择分类", selection: $viewModel.selectedCategory) {
                        Text("全部分类").tag(nil as ExpenseCategory?)
                        ForEach(ExpenseCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                    .foregroundColor(category.color)
                                Text(category.displayName)
                            }
                            .tag(category as ExpenseCategory?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("时间范围") {
                    DatePicker("开始日期", selection: Binding(
                        get: { viewModel.startDate ?? Date() },
                        set: { viewModel.startDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("结束日期", selection: Binding(
                        get: { viewModel.endDate ?? Date() },
                        set: { viewModel.endDate = $0 }
                    ), displayedComponents: .date)
                    
                    Button("清除时间范围") {
                        viewModel.startDate = nil
                        viewModel.endDate = nil
                    }
                    .foregroundColor(.blue)
                }
                
                Section("搜索") {
                    TextField("搜索描述、分类或地点", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("排序") {
                    Picker("排序方式", selection: $viewModel.sortBy) {
                        ForEach(ExpenseViewModel.SortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("排序顺序", selection: $viewModel.sortOrder) {
                        ForEach(ExpenseViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 支出详情视图
struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 金额显示
                    VStack(spacing: 8) {
                        Text(expense.formattedAmount)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text((ExpenseCategory(rawValue: expense.category) ?? .other).displayName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 详细信息卡片
                    VStack(spacing: 16) {
                        ExpenseDetailRow(
                            icon: "doc.text",
                            title: "描述",
                            value: expense.description,
                            color: .blue
                        )
                        
                        ExpenseDetailRow(
                            icon: "calendar",
                            title: "日期",
                            value: formatFullDate(expense.date),
                            color: .green
                        )
                        
                        if let location = expense.location, !location.isEmpty {
                            ExpenseDetailRow(
                                icon: "location",
                                title: "地点",
                                value: location,
                                color: .orange
                            )
                        }
                        
                        ExpenseDetailRow(
                            icon: (PaymentMethod(rawValue: expense.paymentMethod) ?? .cash).iconName,
                            title: "支付方式",
                            value: (PaymentMethod(rawValue: expense.paymentMethod) ?? .cash).displayName,
                            color: (PaymentMethod(rawValue: expense.paymentMethod) ?? .cash).color
                        )
                        
                        if !expense.tags.isEmpty {
                            ExpenseDetailRow(
                                icon: "tag",
                                title: "标签",
                                value: expense.tags.joined(separator: ", "),
                                color: .purple
                            )
                        }
                        
                        // notes字段已从API中移除
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("支出详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 支出详情行
struct ExpenseDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 预览
#if DEBUG
struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseListView()
    }
}
#endif
