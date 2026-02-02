import SwiftUI

/// 根据 API 返回的 content_json 通用渲染法律文档（隐私/条款/Cookie），按 documentType 固定顺序
struct LegalDocumentContentView: View {
    let contentJson: [String: JSONValue]
    /// 文档类型：privacy / terms / cookie，用于确定章节顺序
    let documentType: String
    private var sections: [(title: String, paragraphs: [String])] {
        JSONValue.sections(from: contentJson, type: documentType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(AppTypography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    ForEach(section.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(AppSpacing.md)
                .cardStyle()
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .padding(.vertical, AppSpacing.md)
    }
}
