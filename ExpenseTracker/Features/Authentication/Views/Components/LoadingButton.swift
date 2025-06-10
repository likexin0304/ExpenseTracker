import SwiftUI

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    var style: ButtonStyle = .primary
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style == .primary ? .white : .systemBlue))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
        .modifier(ButtonStyleModifier(style: style))
    }
}

struct ButtonStyleModifier: ViewModifier {
    let style: LoadingButton.ButtonStyle
    
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.primaryButtonStyle()
        case .secondary:
            content.secondaryButtonStyle()
        }
    }
}
