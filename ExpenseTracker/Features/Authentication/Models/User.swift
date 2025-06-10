import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let wechatOpenId: String?
    let createdAt: String
    let updatedAt: String
}
