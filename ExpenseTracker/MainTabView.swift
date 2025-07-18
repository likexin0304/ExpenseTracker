import SwiftUI

/**
 * 主应用视图
 * 包含底部标签栏和主要功能页面
 */
struct MainTabView: View {
    @StateObject private var expenseViewModel = ExpenseViewModel()
    @EnvironmentObject var budgetViewModel: BudgetViewModel
    @StateObject private var autoOCRViewModel = AutoOCRViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(0)
                .environmentObject(expenseViewModel)
                .environmentObject(budgetViewModel)
            
            // 支出列表
            ExpenseListView()
                .tabItem {
                    Label("支出", systemImage: "list.bullet")
                }
                .tag(1)
                .environmentObject(expenseViewModel)
            
            // 智能识别
            AutoOCRView()
                .tabItem {
                    Label("识别", systemImage: "camera.viewfinder")
                }
                .tag(2)
                .environmentObject(autoOCRViewModel)
            
            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(3)
                .environmentObject(AuthViewModel.shared)
        }
    }
} 