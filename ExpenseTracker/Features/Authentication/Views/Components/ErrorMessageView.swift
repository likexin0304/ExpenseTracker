import SwiftUI

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.systemRed)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.systemRed)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemRed.opacity(0.1))
        .cornerRadius(8)
    }
}
