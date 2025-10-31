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
    
    // MARK: - 自定义解码器
    enum CodingKeys: String, CodingKey {
        case id, email, username, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID字段 - 支持UUID格式
        id = try container.decode(String.self, forKey: .id)
        
        // Email字段
        email = try container.decode(String.self, forKey: .email)
        
        // Username字段 - 可选
        username = try container.decodeIfPresent(String.self, forKey: .username)
        
        // 日期字段 - 支持ISO8601格式
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // CreatedAt
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = formatter.date(from: createdAtString) ?? Date()
            print("✅ User.createdAt解码成功: \(createdAtString)")
        } else {
            createdAt = Date()
            print("⚠️ User.createdAt使用默认值")
        }
        
        // UpdatedAt
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = formatter.date(from: updatedAtString) ?? Date()
            print("✅ User.updatedAt解码成功: \(updatedAtString)")
        } else {
            updatedAt = Date()
            print("⚠️ User.updatedAt使用默认值")
        }
        
        print("✅ User模型解码成功: id=\(id), email=\(email)")
    }
}
