import Foundation
import Combine

/**
 * 响应处理器
 * 处理不同格式的API响应，提供更灵活的解析方案
 */
class ResponseHandler {
    
    /// 创建配置好的JSONDecoder
    private static func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    /**
     * 智能解析API响应
     * 自动适配有message和无message的响应格式
     */
    static func parseResponse<T: Codable>(
        data: Data,
        responseType: T.Type
    ) -> Result<APIResponse<T>, NetworkError> {
        
        let decoder = createJSONDecoder()
        
        // 首先尝试解析为标准APIResponse格式
        if let standardResponse = try? decoder.decode(APIResponse<T>.self, from: data) {
            return .success(standardResponse)
        }
        
        // 如果标准格式失败，尝试解析为无message的格式
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let jsonDict = json else {
                return .failure(.decodingError(NSError(domain: "ResponseHandler", code: 100, userInfo: [NSLocalizedDescriptionKey: "无法解析为JSON字典"])))
            }
            
            let success = jsonDict["success"] as? Bool ?? false
            let message = jsonDict["message"] as? String // 可选
            let errorMessage = jsonDict["error"] as? String // 可选错误信息
            
            // 尝试解析data字段
            var responseData: T? = nil
            if let dataJson = jsonDict["data"] {
                let dataJsonData = try JSONSerialization.data(withJSONObject: dataJson, options: [])
                responseData = try? createJSONDecoder().decode(T.self, from: dataJsonData)
            }
            
            if let responseData = responseData {
                let response = APIResponse<T>(success: success, data: responseData, message: message, error: errorMessage)
                return .success(response)
            } else {
                return .failure(.decodingError(NSError(domain: "ResponseHandler", code: 101, userInfo: [NSLocalizedDescriptionKey: "无法解析数据字段"])))
            }
            
        } catch {
            print("❌ 智能解析也失败了: \(error)")
            return .failure(.decodingError(error))
        }
    }
}
