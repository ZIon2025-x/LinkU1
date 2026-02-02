import Foundation

// MARK: - 法律文档库 API 模型（与后端 GET /api/legal/{type} 一致）

struct LegalDocumentOut: Decodable {
    let type: String
    let lang: String
    let version: String?
    let effectiveAt: String?
    let contentJson: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, lang, version
        case effectiveAt = "effective_at"
        case contentJson = "content_json"
    }
}

/// 用于解码任意 JSON 的 content_json
enum JSONValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type"))
    }

    /// 按路径取字符串，路径如 "dataCollection.title"
    static func getString(from dict: [String: JSONValue]?, path: String) -> String? {
        guard let dict = dict else { return nil }
        let parts = path.split(separator: ".").map(String.init)
        var current: JSONValue = .object(dict)
        for part in parts {
            switch current {
            case .object(let o):
                guard let next = o[part] else { return nil }
                current = next
            default:
                return nil
            }
        }
        if case .string(let s) = current { return s }
        return nil
    }

    /// 将 content_json 转为可遍历的「标题 + 段落」列表（与 locale 结构一致：顶层 string 为单段，object 为 section 含 title 与若干 string）
    static func sections(from dict: [String: JSONValue]?) -> [(title: String, paragraphs: [String])] {
        guard let dict = dict else { return [] }
        var result: [(title: String, paragraphs: [String])] = []
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            switch value {
            case .string(let s):
                result.append((title: key, paragraphs: [s]))
            case .object(let o):
                var title = ""
                var paragraphs: [String] = []
                for (k, v) in o.sorted(by: { $0.key < $1.key }) {
                    if case .string(let s) = v {
                        if k == "title" { title = s } else { paragraphs.append(s) }
                    }
                }
                if !title.isEmpty || !paragraphs.isEmpty {
                    result.append((title: title, paragraphs: paragraphs))
                }
            default:
                break
            }
        }
        return result
    }
}
