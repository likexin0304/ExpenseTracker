import SwiftUI

struct BackTapLogsView: View {
    @ObservedObject var viewModel: AutoRecognitionViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var showOnlyBackTapLogs = true
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 过滤选项
                Toggle("只显示背面敲击日志", isOn: $showOnlyBackTapLogs)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // 日志内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if viewModel.backTapLogs.isEmpty {
                            Text("暂无日志记录")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredLogs, id: \.self) { log in
                                LogEntryView(logEntry: log)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // 操作按钮
                HStack {
                    Button(action: {
                        viewModel.fetchBackTapLogs()
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.clearLogs()
                    }) {
                        Label("清除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("背面敲击日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.fetchBackTapLogs()
            }
        }
    }
    
    // 过滤日志
    private var filteredLogs: [String] {
        let allLogs = viewModel.backTapLogs.components(separatedBy: "\n")
        
        return allLogs.filter { log in
            // 应用搜索过滤
            let matchesSearch = searchText.isEmpty || log.localizedCaseInsensitiveContains(searchText)
            
            // 应用类别过滤
            let matchesCategory = !showOnlyBackTapLogs || log.contains("[BackTap]")
            
            return matchesSearch && matchesCategory
        }
    }
}

// 单条日志条目视图
struct LogEntryView: View {
    let logEntry: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(logEntry)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .foregroundColor(textColor)
                .padding(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(6)
    }
    
    // 根据日志类型设置不同颜色
    private var backgroundColor: Color {
        if logEntry.contains("[ERROR]") || logEntry.contains("[CRITICAL]") {
            return Color(.systemRed).opacity(0.1)
        } else if logEntry.contains("[WARNING]") {
            return Color(.systemYellow).opacity(0.1)
        } else if logEntry.contains("[BackTap]") {
            return Color(.systemBlue).opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        if logEntry.contains("[ERROR]") || logEntry.contains("[CRITICAL]") {
            return .red
        } else if logEntry.contains("[WARNING]") {
            return .orange
        } else if logEntry.contains("[BackTap]") {
            return .blue
        } else {
            return .primary
        }
    }
}

// 预览
struct BackTapLogsView_Previews: PreviewProvider {
    static var previews: some View {
        BackTapLogsView(viewModel: AutoRecognitionViewModel.shared)
    }
} 