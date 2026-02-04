import Foundation

// MARK: - 法律文档库 API 模型（与后端 GET /api/legal/{type} 一致）

struct LegalDocumentOut: Codable {
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
enum JSONValue: Codable {
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .bool(let b):
            try container.encode(b)
        case .object(let o):
            try container.encode(o)
        case .array(let a):
            try container.encode(a)
        }
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

    /// 按文档类型固定的 key 顺序，保证展示顺序与协议一致（不再按字母序）
    private static func orderKeys(for documentType: String) -> [String] {
        switch documentType {
        case "terms":
            return ["title", "lastUpdated", "version", "effectiveDate", "jurisdiction", "operatorInfo", "operator", "contact",
                    "serviceNature", "userTypes", "platformPosition", "feesAndRules", "pointsRules", "couponRules", "paymentAndRefund", "prohibitedTasks",
                    "userBehavior", "userResponsibilities", "intellectualProperty", "privacyData", "disclaimer", "termination",
                    "disputes", "forumTerms", "fleaMarketTerms", "consumerAppendix", "importantNotice"]
        case "privacy":
            return ["title", "lastUpdated", "version", "effectiveDate", "controller", "operator", "contactEmail", "address", "dpoNote",
                    "dataCollection", "dataSharing", "internationalTransfer", "retentionPeriod", "yourRights", "cookies", "contactUs", "importantNotice"]
        case "cookie":
            return ["title", "version", "effectiveDate", "jurisdiction", "intro", "whatAreCookies", "typesWeUse", "thirdParty",
                    "retention", "howToManage", "mobileTech", "yourRights", "contactUs", "importantNotice", "necessary", "optional", "contact"]
        default:
            return []
        }
    }

    /// 将 content_json 转为可遍历的「标题 + 段落」列表，按 documentType 固定顺序（与 Web 一致）
    static func sections(from dict: [String: JSONValue]?, type documentType: String) -> [(title: String, paragraphs: [String])] {
        guard let dict = dict else { return [] }
        let order = orderKeys(for: documentType)
        if order.isEmpty {
            return sectionsFallback(from: dict)
        }
        var result: [(title: String, paragraphs: [String])] = []
        for key in order {
            guard let value = dict[key] else { continue }
            switch value {
            case .string(let s):
                if key == "title" { continue }
                result.append((title: key, paragraphs: [s]))
            case .object(let o):
                var title = ""
                var paragraphs: [String] = []
                let innerOrder = objectParagraphOrder(for: o)
                for k in innerOrder {
                    guard let v = o[k], case .string(let s) = v else { continue }
                    if k == "title" { title = s } else { paragraphs.append(s) }
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

    /// 子对象内段落顺序：title → introduction → p1,p2.. 数字序 → 其余字母序
    private static func objectParagraphOrder(for o: [String: JSONValue]) -> [String] {
        let priorityOrder = ["title", "introduction"]
        return o.keys.sorted { a, b in
            let ia = priorityOrder.firstIndex(of: a) ?? .max
            let ib = priorityOrder.firstIndex(of: b) ?? .max
            if ia != .max || ib != .max { return ia < ib }
            let pa = a.hasPrefix("p") ? Int(a.dropFirst(1)) : nil
            let pb = b.hasPrefix("p") ? Int(b.dropFirst(1)) : nil
            if let na = pa, let nb = pb { return na < nb }
            if pa != nil { return true }
            if pb != nil { return false }
            return a < b
        }
    }

    /// 未知类型时按 key 字母序回退（兼容旧数据）
    private static func sectionsFallback(from dict: [String: JSONValue]) -> [(title: String, paragraphs: [String])] {
        var result: [(title: String, paragraphs: [String])] = []
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            switch value {
            case .string(let s):
                if key == "title" { continue }
                result.append((title: key, paragraphs: [s]))
            case .object(let o):
                var title = ""
                var paragraphs: [String] = []
                for k in objectParagraphOrder(for: o) {
                    guard let v = o[k], case .string(let s) = v else { continue }
                    if k == "title" { title = s } else { paragraphs.append(s) }
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
