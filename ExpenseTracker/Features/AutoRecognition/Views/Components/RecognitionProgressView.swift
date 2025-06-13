import SwiftUI

struct RecognitionProgressView: View {
    let state: AutoRecognitionState
    let progress: Double
    let progressMessage: String
    let onCancel: () -> Void
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // 状态图标
            stateIcon
            
            // 状态文本
            Text(stateDisplayText)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 进度条（仅在处理中显示）
            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Text(progressMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 等待确认倒计时
            if case .waitingForConfirmation = state {
                CountdownView(duration: 2.0)
            }
            
            // 操作按钮
            actionButtons
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 300)
    }
    
    // MARK: - 状态图标
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
        
        case .waitingForConfirmation:
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
        
        case .capturingScreen:
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
        
        case .recognizing:
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
        
        case .parsing:
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
        
        case .success(_):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .symbolEffect(.bounce)
        
        case .failed(_):
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
        
        case .cancelled:
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - 状态文本
    private var stateDisplayText: String {
        switch state {
        case .idle:
            return "等待触发"
        case .waitingForConfirmation:
            return "即将开始识别..."
        case .capturingScreen:
            return "正在截取屏幕"
        case .recognizing:
            return "正在识别文字"
        case .parsing:
            return "正在解析数据"
        case .success(_):
            return "识别成功！"
        case .failed(_):
            return "识别失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    // MARK: - 是否正在处理
    private var isProcessing: Bool {
        switch state {
        case .capturingScreen, .recognizing, .parsing:
            return true
        default:
            return false
        }
    }
    
    // MARK: - 操作按钮
    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .waitingForConfirmation, .capturingScreen, .recognizing, .parsing:
            Button("取消") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        
        case .failed(_), .cancelled:
            Button("关闭") {
                onCancel()
            }
            .buttonStyle(.borderedProminent)
        
        default:
            EmptyView()
        }
    }
}

// MARK: - 倒计时视图
struct CountdownView: View {
    let duration: Double
    @State private var timeRemaining: Double
    @State private var timer: Timer?
    
    init(duration: Double) {
        self.duration = duration
        self._timeRemaining = State(initialValue: duration)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(1 - timeRemaining / duration))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timeRemaining)
                
                Text("\(Int(ceil(timeRemaining)))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text("点击屏幕任意位置取消")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 浮动状态指示器
struct FloatingStatusIndicator: View {
    let state: AutoRecognitionState
    let isEnabled: Bool
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: isEnabled ? "hand.tap.fill" : "hand.tap")
                .font(.caption)
        case .waitingForConfirmation:
            Image(systemName: "clock.fill")
                .font(.caption)
                .symbolEffect(.pulse)
        case .capturingScreen, .recognizing, .parsing:
            Image(systemName: "circle.dotted")
                .font(.caption)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
        case .failed(_):
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
        case .cancelled:
            Image(systemName: "stop.circle.fill")
                .font(.caption)
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return isEnabled ? "敲击3下识别" : "识别已关闭"
        case .waitingForConfirmation:
            return "准备识别"
        case .capturingScreen:
            return "截图中"
        case .recognizing:
            return "识别中"
        case .parsing:
            return "解析中"
        case .success(_):
            return "识别成功"
        case .failed(_):
            return "识别失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .idle:
            return isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1)
        case .waitingForConfirmation, .capturingScreen, .recognizing, .parsing:
            return Color.orange.opacity(0.1)
        case .success(_):
            return Color.green.opacity(0.1)
        case .failed(_):
            return Color.red.opacity(0.1)
        case .cancelled:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        switch state {
        case .idle:
            return isEnabled ? .blue : .gray
        case .waitingForConfirmation, .capturingScreen, .recognizing, .parsing:
            return .orange
        case .success(_):
            return .green
        case .failed(_):
            return .red
        case .cancelled:
            return .gray
        }
    }
}

// MARK: - 预览
#if DEBUG
struct RecognitionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RecognitionProgressView(
                state: .waitingForConfirmation,
                progress: 0.0,
                progressMessage: "",
                onCancel: {}
            )
            .previewDisplayName("等待确认")
            
            RecognitionProgressView(
                state: .recognizing,
                progress: 0.6,
                progressMessage: "正在识别文字...",
                onCancel: {}
            )
            .previewDisplayName("识别中")
            
            RecognitionProgressView(
                state: .success(RecognitionResult(amounts: [25.80], rawText: "测试", suggestedCategory: .food)),
                progress: 1.0,
                progressMessage: "识别完成",
                onCancel: {}
            )
            .previewDisplayName("识别成功")
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
}

struct FloatingStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            FloatingStatusIndicator(state: .idle, isEnabled: true)
            FloatingStatusIndicator(state: .recognizing, isEnabled: true)
            FloatingStatusIndicator(state: .success(RecognitionResult(amounts: [25.80], rawText: "测试", suggestedCategory: .food)), isEnabled: true)
            FloatingStatusIndicator(state: .failed(.ocrFailed("识别失败")), isEnabled: true)
        }
        .padding()
    }
}
#endif 