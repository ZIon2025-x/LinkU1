import SwiftUI

/// 可翻译的文本组件 - 自动检测语言并翻译
struct TranslatableText: View {
    let text: String
    let font: Font?
    let foregroundColor: Color?
    let lineLimit: Int?
    let lineSpacing: CGFloat?
    let isOriginal: Bool // 是否显示原文（用于切换）
    
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var showOriginal = false
    @State private var needsTranslation = false
    
    init(
        _ text: String,
        font: Font? = nil,
        foregroundColor: Color? = nil,
        lineLimit: Int? = nil,
        lineSpacing: CGFloat? = nil,
        isOriginal: Bool = false
    ) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineLimit = lineLimit
        self.lineSpacing = lineSpacing
        self.isOriginal = isOriginal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 显示文本（翻译后的或原文）
            Text(showOriginal || !needsTranslation ? text : (translatedText ?? text))
                .font(font)
                .foregroundColor(foregroundColor)
                .lineLimit(lineLimit)
                .lineSpacing(lineSpacing ?? 0)
                .textSelection(.enabled) // 支持文本选择，用户可以使用系统翻译
                .onAppear {
                    if !isOriginal && !text.isEmpty {
                        checkAndTranslate()
                    }
                }
            
            // 翻译状态和切换按钮
            if needsTranslation && !isOriginal {
                HStack(spacing: 6) {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(LocalizationKey.translationTranslating.localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if let translated = translatedText, translated != text {
                        Button(action: {
                            showOriginal.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showOriginal ? "arrow.uturn.backward" : "text.bubble")
                                    .font(.system(size: 10))
                                Text(showOriginal ? "显示翻译" : "显示原文")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    /// 检查并翻译文本
    private func checkAndTranslate() {
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            // 检查是否需要翻译
            let needs = TranslationService.shared.needsTranslation(text)
            needsTranslation = needs
            
            if needs {
                // 需要翻译，执行翻译
                isTranslating = true
                do {
                    let translated = try await TranslationService.shared.translate(text)
                    translatedText = translated
                    // 默认显示翻译后的文本
                    showOriginal = false
                } catch {
                    Logger.error("翻译失败: \(error.localizedDescription)", category: .ui)
                    // 翻译失败时显示原文
                    translatedText = nil
                }
                isTranslating = false
            }
        }
    }
}
