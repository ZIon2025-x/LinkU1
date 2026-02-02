import SwiftUI
import Combine

struct FAQView: View {
    @Environment(\.locale) var locale
    @State private var expandedSections: Set<String> = []
    @State private var expandedItems: Set<String> = []
    @State private var apiSections: [FaqSectionOut]?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var faqCancellable: AnyCancellable?

    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    private var faqLang: String { isChinese ? "zh" : "en" }

    private var faqSections: [FAQSection] {
        guard let list = apiSections else { return [] }
        return list.map { sec in
            FAQSection(
                id: "\(sec.id)",
                title: sec.title,
                items: sec.items.enumerated().map { idx, it in
                    FAQItem(
                        id: "\(it.id)",
                        question: it.question,
                        answer: it.answer,
                        isOpen: idx == 0
                    )
                }
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(isChinese ? "我们整理了常见问题与答案，帮助你更快上手 Link²Ur（任务、跳蚤市场、论坛与支付等）。" : "We compiled common questions and answers to help you get started with Link²Ur — tasks, flea market, forum, and payments.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                if isLoading {
                    Text(isChinese ? "加载中…" : "Loading…")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.lg)
                } else if let err = loadError {
                    Text(err)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal, AppSpacing.md)
                } else {
                    ForEach(faqSections) { section in
                        FAQSectionView(
                            section: section,
                            isExpanded: expandedSections.contains(section.id),
                            expandedItems: expandedItems,
                            onToggleSection: {
                                if expandedSections.contains(section.id) {
                                    expandedSections.remove(section.id)
                                } else {
                                    expandedSections.insert(section.id)
                                }
                            },
                            onToggleItem: { itemId in
                                if expandedItems.contains(itemId) {
                                    expandedItems.remove(itemId)
                                } else {
                                    expandedItems.insert(itemId)
                                }
                            }
                        )
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle(isChinese ? "常见问题" : "FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { loadFaq() }
        .onChange(of: faqLang) { _ in loadFaq() }
    }

    private func loadFaq() {
        isLoading = true
        loadError = nil
        faqCancellable = APIService.shared.getFaq(lang: faqLang)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure = completion {
                        loadError = isChinese ? "加载常见问题失败，请稍后重试。" : "Failed to load FAQ. Please try again later."
                    }
                },
                receiveValue: { response in
                    apiSections = response.sections
                }
            )
    }
}

struct FAQSection: Identifiable {
    let id: String
    let title: String
    let items: [FAQItem]
}

struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
    var isOpen: Bool = false
}

struct FAQSectionView: View {
    let section: FAQSection
    let isExpanded: Bool
    let expandedItems: Set<String>
    let onToggleSection: () -> Void
    let onToggleItem: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleSection()
                }
            }) {
                HStack {
                    Text(section.title)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(section.items) { item in
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        FAQItemView(
                            item: item,
                            isExpanded: expandedItems.contains(item.id) || item.isOpen,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    onToggleItem(item.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct FAQItemView: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(item.question)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, AppSpacing.md)
                
                Text(item.answer)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .padding(AppSpacing.md)
                    .padding(.top, AppSpacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationView {
        FAQView()
    }
}
