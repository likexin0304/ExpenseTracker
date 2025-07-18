import Foundation

/**
 * 用户模型
 */
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String, email: String, username: String, createdAt: Date, updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
