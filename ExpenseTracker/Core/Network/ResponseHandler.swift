import Foundation
import Combine

/**
 * 响应处理器
 * 处理不同格式的API响应，提供更灵活的解析方案
 */
class ResponseHandler {
    
    /**
     * 智能解析API响应
     * 自动适配有message和无message的响应格式
     */
    static func parseResponse<T: Codable>(
        data: Data,
        responseType: T.Type
    ) -> Result<APIResponse<T>, NetworkError> {
        
        let decoder = JSONDecoder()
        
        // 首先尝试解析为标准APIResponse格式
        if let standardResponse = try? decoder.decode(APIResponse<T>.self, from: data) {
            return .success(standardResponse)
        }
        
        // 如果标准格式失败，尝试解析为无message的格式
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let jsonDict = json else {
                return .failure(.decodingError)
            }
            
            let success = jsonDict["success"] as? Bool ?? false
            let message = jsonDict["message"] as? String // 可选
            
            // 尝试解析data字段
            var responseData: T? = nil
            if let dataJson = jsonDict["data"] {
                let dataJsonData = try JSONSerialization.data(withJSONObject: dataJson, options: [])
                responseData = try? decoder.decode(T.self, from: dataJsonData)
            }
            
            let response = APIResponse<T>(success: success, message: message, data: responseData!)
            return .success(response)
            
        } catch {
            print("❌ 智能解析也失败了: \(error)")
            return .failure(.decodingError)
        }
    }
}
