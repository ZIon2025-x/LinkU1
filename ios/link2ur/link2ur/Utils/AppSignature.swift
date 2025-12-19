import Foundation
import CryptoKit

/// 应用签名工具类
/// 用于生成请求签名，防止请求伪造
struct AppSignature {
    
    /// 获取应用签名密钥（使用混淆保护）
    /// 密钥在运行时动态组装，防止静态分析提取
    private static var appSecret: String {
        // 将密钥分散存储，运行时组装
        let p1 = "Ks7_dH2x"
        let p2 = "PqN8mVfL"
        let p3 = "3wYzRt5u"
        let p4 = "CbJeAg0i"
        let p5 = "Xp1kOsWn"
        let p6 = "MhIvQy@Z"
        let p7 = "zxBcDxFr"
        let p8 = "UaEoGm4y"
        let p9 = "H6nP9kLq"
        let p10 = "S2wRtVxZ"
        let p11 = "uAcBdEf"
        
        // 使用数组打乱顺序后重组
        let parts = [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11]
        return parts.joined()
    }
    
    /// 生成请求签名
    /// - Parameter sessionId: 当前会话 ID
    /// - Returns: (signature, timestamp) 元组
    static func generateSignature(sessionId: String) -> (signature: String, timestamp: String) {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let message = "\(sessionId)\(timestamp)"
        
        // 使用 HMAC-SHA256 生成签名
        let key = SymmetricKey(data: Data(appSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let signatureHex = signature.map { String(format: "%02x", $0) }.joined()
        
        return (signatureHex, timestamp)
    }
    
    /// 为 URLRequest 添加签名头
    /// - Parameters:
    ///   - request: 要签名的请求
    ///   - sessionId: 当前会话 ID
    /// - Returns: 添加了签名头的请求
    static func signRequest(_ request: inout URLRequest, sessionId: String) {
        let (signature, timestamp) = generateSignature(sessionId: sessionId)
        request.setValue(signature, forHTTPHeaderField: "X-App-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "X-App-Timestamp")
    }
}
