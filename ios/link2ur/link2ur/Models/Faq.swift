import Foundation

// MARK: - FAQ 库 API 模型（与后端 GET /api/faq 一致）

struct FaqItemOut: Codable, Identifiable {
    let id: Int
    let question: String
    let answer: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, question, answer
        case sortOrder = "sort_order"
    }
}

struct FaqSectionOut: Codable, Identifiable {
    let id: Int
    let key: String
    let title: String
    let items: [FaqItemOut]
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, key, title, items
        case sortOrder = "sort_order"
    }
}

struct FaqListResponse: Codable {
    let sections: [FaqSectionOut]
}
