import Foundation
import Compression

/// 压缩辅助工具 - 企业级数据压缩
public struct CompressionHelper {
    
    /// 压缩数据
    public static func compress(_ data: Data, algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        let bufferSize = data.count
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { sourceBuffer in
            compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                bufferSize,
                nil,
                algorithm
            )
        }
        
        guard compressedSize > 0 else {
            return nil
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
    }
    
    /// 解压数据
    public static func decompress(_ data: Data, algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        let bufferSize = data.count * 4 // 估算解压后大小
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes { sourceBuffer in
            compression_decode_buffer(
                destinationBuffer,
                bufferSize,
                sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                algorithm
            )
        }
        
        guard decompressedSize > 0 else {
            return nil
        }
        
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
    
    /// 压缩字符串
    public static func compressString(_ string: String) -> Data? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        return compress(data)
    }
    
    /// 解压字符串
    public static func decompressString(_ data: Data) -> String? {
        guard let decompressed = decompress(data),
              let string = String(data: decompressed, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

