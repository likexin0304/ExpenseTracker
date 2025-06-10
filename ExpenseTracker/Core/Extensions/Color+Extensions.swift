import SwiftUI

extension Color {
    // 自定义颜色（将来可以在Assets.xcassets中定义）
    static let primaryBlue = Color.blue
    static let backgroundGray = Color.gray.opacity(0.1)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    // iOS系统颜色（正确转换）
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
    
    // 系统蓝色系列
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemIndigo = Color(UIColor.systemIndigo)
    static let systemPurple = Color(UIColor.systemPurple)
    
    // 系统红色系列
    static let systemRed = Color(UIColor.systemRed)
    static let systemPink = Color(UIColor.systemPink)
    static let systemOrange = Color(UIColor.systemOrange)
    
    // 系统绿色系列
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemMint = Color(UIColor.systemMint)
    static let systemTeal = Color(UIColor.systemTeal)
    
    // 系统黄色系列
    static let systemYellow = Color(UIColor.systemYellow)
    
    // 系统灰色系列
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray2 = Color(UIColor.systemGray2)
    static let systemGray3 = Color(UIColor.systemGray3)
    static let systemGray4 = Color(UIColor.systemGray4)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)
    
    // 标签颜色
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
}
