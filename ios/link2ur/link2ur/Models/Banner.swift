import Foundation

// MARK: - Banner (广告横幅)

struct Banner: Codable, Identifiable {
    let id: Int
    let imageUrl: String
    let title: String // 后端：nullable=False，必需字段
    let subtitle: String? // 后端：nullable=True，可选字段
    let linkUrl: String? // 后端：nullable=True，可选字段
    let linkType: String // 后端：default="internal"，有默认值，但API返回时总是存在
    let order: Int // 后端：default=0，有默认值，但API返回时总是存在
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case title
        case subtitle
        case linkUrl = "link_url"
        case linkType = "link_type"
        case order
    }
}

// MARK: - Banner List Response

struct BannerListResponse: Codable {
    let banners: [Banner]
    
    enum CodingKeys: String, CodingKey {
        case banners
    }
}
