import SwiftUI

// MARK: - 增强型输入框组件系统

/// 输入框状态
enum FieldState {
    case normal
    case focused
    case error
    case success
}


/// 增强型文本输入框
struct EnhancedTextField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    var showPasswordToggle: Bool = false
    var errorMessage: String? = nil
    var helperText: String? = nil
    var isRequired: Bool = false
    var onSubmit: (() -> Void)? = nil
    var onFocusChange: ((Bool) -> Void)? = nil
    var scrollId: AnyHashable? = nil
    
    @FocusState private var isFocused: Bool
    @State private var showPassword: Bool = false
    
    private var fieldState: FieldState {
        if let _ = errorMessage {
            return .error
        } else if isFocused {
            return .focused
        } else if !text.isEmpty && errorMessage == nil {
            return .success
        }
        return .normal
    }
    
    private var borderColor: Color {
        switch fieldState {
        case .normal:
            return AppColors.separator.opacity(text.isEmpty ? 0.3 : 0.5)
        case .focused:
            return AppColors.primary
        case .error:
            return AppColors.error
        case .success:
            return AppColors.success.opacity(0.6)
        }
    }
    
    private var borderWidth: CGFloat {
        switch fieldState {
        case .focused, .error:
            return 1.5
        default:
            return 1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 标题
            if let title = title {
                HStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if isRequired {
                        Text("*")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            
            // 输入框容器
            HStack(spacing: AppSpacing.sm) {
                // 图标
                if let icon = icon {
                    IconStyle.icon(icon, size: IconStyle.medium)
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                // 输入框
                Group {
                    if isSecure && !showPassword {
                        SecureField(placeholder, text: $text)
                            .font(AppTypography.body)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .textInputAutocapitalization(autocapitalization)
                            .focused($isFocused)
                            .onChange(of: isFocused) { focused in
                                onFocusChange?(focused)
                            }
                            .onSubmit {
                                onSubmit?()
                            }
                    } else {
                        TextField(placeholder, text: $text)
                            .font(AppTypography.body)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .textInputAutocapitalization(autocapitalization)
                            .focused($isFocused)
                            .onChange(of: isFocused) { focused in
                                onFocusChange?(focused)
                            }
                            .onSubmit {
                                onSubmit?()
                            }
                    }
                }
                
                // 密码显示/隐藏按钮
                if isSecure && showPasswordToggle {
                    Button(action: {
                        withAnimation(.spring(response: 0.2)) {
                            showPassword.toggle()
                        }
                    }) {
                        IconStyle.icon(showPassword ? "eye.slash.fill" : "eye.fill", size: IconStyle.medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // 清除按钮
                if !text.isEmpty && !isSecure {
                    Button(action: {
                        withAnimation {
                            text = ""
                        }
                    }) {
                        IconStyle.icon("xmark.circle.fill", size: IconStyle.small)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // 状态图标
                if fieldState == .success && !text.isEmpty {
                    IconStyle.icon("checkmark.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.success)
                } else if fieldState == .error {
                    IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .animation(.easeInOut(duration: 0.2), value: fieldState)
            .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            .id(scrollId)
            
            // 错误消息或帮助文本
            if let errorMessage = errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let helperText = helperText {
                Text(helperText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .transition(.opacity)
            }
        }
    }
    
    private var iconColor: Color {
        switch fieldState {
        case .focused:
            return AppColors.primary
        case .error:
            return AppColors.error
        case .success:
            return AppColors.success
        default:
            return AppColors.textSecondary
        }
    }
}

/// 增强型多行文本编辑器
struct EnhancedTextEditor: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 120
    var errorMessage: String? = nil
    var helperText: String? = nil
    var isRequired: Bool = false
    var characterLimit: Int? = nil
    
    @FocusState private var isFocused: Bool
    
    private var fieldState: FieldState {
        if let _ = errorMessage {
            return .error
        } else if isFocused {
            return .focused
        }
        return .normal
    }
    
    private var borderColor: Color {
        switch fieldState {
        case .normal:
            return AppColors.separator.opacity(0.3)
        case .focused:
            return AppColors.primary
        case .error:
            return AppColors.error
        case .success:
            return AppColors.success.opacity(0.6)
        }
    }
    
    private var borderWidth: CGFloat {
        switch fieldState {
        case .focused, .error:
            return 1.5
        default:
            return 1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 标题
            if let title = title {
                HStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if isRequired {
                        Text("*")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.error)
                    }
                    
                    Spacer()
                    
                    // 字符计数
                    if let limit = characterLimit {
                        Text("\(text.count)/\(limit)")
                            .font(AppTypography.caption)
                            .foregroundColor(text.count > limit ? AppColors.error : AppColors.textTertiary)
                    }
                }
            }
            
            // 文本编辑器容器
            ZStack(alignment: .topLeading) {
                // 占位符
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppTypography.body)
                        .foregroundColor(Color(UIColor.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                
                // 文本编辑器
                TextEditor(text: $text)
                    .font(AppTypography.body)
                    .frame(height: height)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        // 限制字符数
                        if let limit = characterLimit, newValue.count > limit {
                            text = String(newValue.prefix(limit))
                        }
                    }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .animation(.easeInOut(duration: 0.2), value: fieldState)
            
            // 错误消息或帮助文本
            if let errorMessage = errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let helperText = helperText {
                Text(helperText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .transition(.opacity)
            }
        }
    }
}

/// 增强型数字输入框
struct EnhancedNumberField: View {
    let title: String?
    let placeholder: String
    @Binding var value: Double?
    var prefix: String? = nil
    var suffix: String? = nil
    var errorMessage: String? = nil
    var helperText: String? = nil
    var isRequired: Bool = false
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    private var fieldState: FieldState {
        if let _ = errorMessage {
            return .error
        } else if isFocused {
            return .focused
        }
        return .normal
    }
    
    private var borderColor: Color {
        switch fieldState {
        case .normal:
            return AppColors.separator.opacity(0.3)
        case .focused:
            return AppColors.primary
        case .error:
            return AppColors.error
        case .success:
            return AppColors.success.opacity(0.6)
        }
    }
    
    private var borderWidth: CGFloat {
        switch fieldState {
        case .focused, .error:
            return 1.5
        default:
            return 1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 标题
            if let title = title {
                HStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if isRequired {
                        Text("*")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            
            // 输入框容器
            HStack(spacing: AppSpacing.sm) {
                // 前缀
                if let prefix = prefix {
                    Text(prefix)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // 输入框
                TextField(placeholder, text: $text)
                    .font(AppTypography.body)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        // 过滤非数字字符（除了小数点）
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if filtered != newValue {
                            text = filtered
                        }
                        
                        // 更新绑定值
                        if filtered.isEmpty {
                            value = nil
                        } else if let doubleValue = Double(filtered) {
                            value = doubleValue
                        }
                    }
                    .onChange(of: value) { newValue in
                        // 只在外部值变化且与当前文本不同时更新
                        if let val = newValue {
                            let formatted = String(format: "%.2f", val)
                            if text != formatted {
                                text = formatted
                            }
                        } else if !text.isEmpty {
                            // 如果值为nil但文本不为空，清空文本
                            text = ""
                        }
                    }
                
                // 后缀
                if let suffix = suffix {
                    Text(suffix)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .animation(.easeInOut(duration: 0.2), value: fieldState)
            
            // 错误消息或帮助文本
            if let errorMessage = errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let helperText = helperText {
                Text(helperText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if let val = value, val > 0 {
                text = String(format: "%.2f", val)
            } else {
                text = ""
            }
        }
    }
}

// MARK: - 通用表单标题组件
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            IconStyle.icon(icon, size: 16)
                .foregroundColor(AppColors.primary)
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - 自定义选择器组件
struct CustomPickerField: View {
    let title: String
    @Binding var selection: String
    let options: [(value: String, label: String)]
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Menu {
                ForEach(options, id: \.value) { option in
                    Button(action: {
                        selection = option.value
                        HapticFeedback.selection()
                    }) {
                        HStack {
                            Text(option.label)
                            if selection == option.value {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let icon = icon {
                        IconStyle.icon(icon, size: 18)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Text(options.first(where: { $0.value == selection })?.label ?? (selection.isEmpty ? LocalizationKey.commonPleaseSelect.localized : selection))
                        .font(AppTypography.body)
                        .foregroundColor(selection.isEmpty ? AppColors.textQuaternary : AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textQuaternary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - 预览
struct EnhancedTextField_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                EnhancedTextField(
                    title: "邮箱",
                    placeholder: "请输入邮箱",
                    text: .constant(""),
                    icon: "envelope.fill",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    isRequired: true
                )
                
                EnhancedTextField(
                    title: "密码",
                    placeholder: "请输入密码",
                    text: .constant("password123"),
                    icon: "lock.fill",
                    isSecure: true,
                    showPasswordToggle: true,
                    isRequired: true
                )
                
                EnhancedTextField(
                    title: "用户名",
                    placeholder: "请输入用户名",
                    text: .constant("user@example.com"),
                    icon: "person.fill",
                    errorMessage: "该邮箱已被注册"
                )
                
                EnhancedTextEditor(
                    title: "描述",
                    placeholder: "请输入详细描述",
                    text: .constant(""),
                    height: 120,
                    isRequired: true,
                    characterLimit: 500
                )
                
                EnhancedNumberField(
                    title: "价格",
                    placeholder: "0.00",
                    value: .constant(nil),
                    prefix: "£",
                    suffix: "GBP"
                )
            }
            .padding()
        }
    }
}
