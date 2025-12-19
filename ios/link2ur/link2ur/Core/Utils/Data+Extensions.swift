import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import CommonCrypto

/// Data 扩展 - 企业级数据处理工具
extension Data {
    
    /// 转换为十六进制字符串
    public var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    /// 从十六进制字符串创建
    public init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// 转换为 Base64 字符串
    public var base64String: String {
        return base64EncodedString()
    }
    
    /// 从 Base64 字符串创建
    public init?(base64String: String) {
        self.init(base64Encoded: base64String)
    }
    
    /// 计算 MD5 哈希
    public var md5: Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes {
            CC_MD5($0.baseAddress, CC_LONG(count), &digest)
        }
        return Data(digest)
    }
    
    /// 计算 SHA256 哈希
    public var sha256: Data {
        #if canImport(CryptoKit)
        return Data(SHA256.hash(data: self))
        #else
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(count), &digest)
        }
        return Data(digest)
        #endif
    }
    
    /// 压缩数据
    public func compressed(using algorithm: CompressionAlgorithm = .zlib) -> Data? {
        return algorithm.compress(self)
    }
    
    /// 解压数据
    public func decompressed(using algorithm: CompressionAlgorithm = .zlib) -> Data? {
        return algorithm.decompress(self)
    }
}

/// 压缩算法
public enum CompressionAlgorithm {
    case zlib
    case lzfse
    case lz4
    case lzma
    
    func compress(_ data: Data) -> Data? {
        // 简化实现，实际应使用 Compression 框架
        return data
    }
    
    func decompress(_ data: Data) -> Data? {
        // 简化实现，实际应使用 Compression 框架
        return data
    }
}

// MARK: - 导入 CommonCrypto

import CommonCrypto

