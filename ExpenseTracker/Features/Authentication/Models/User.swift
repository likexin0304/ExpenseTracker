import Foundation

/**
 * 用户模型
 */
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String?  // 改为可选字段，因为后端可能不返回此字段
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String, email: String, username: String? = nil, createdAt: Date, updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
