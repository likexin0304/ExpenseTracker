import SwiftUI

extension View {
    // 自定义卡片样式
    func cardStyle() -> some View {
        self
            .background(Color.systemBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // 主按钮样式
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.systemBlue)
            .cornerRadius(12)
    }
    
    // 次要按钮样式
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(.systemBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.systemBlue, lineWidth: 1)
            )
    }
    
    // 输入框样式
    func inputFieldStyle() -> some View {
        self
            .padding()
            .background(Color.secondarySystemBackground)
            .cornerRadius(12)
    }
}
