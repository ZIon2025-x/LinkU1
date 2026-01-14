import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: EditProfileViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        avatarSection
                        formContent
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle(LocalizationKey.profileEditProfile.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .alert(LocalizationKey.successSaved.localized, isPresented: $viewModel.showSuccessAlert) {
                Button(LocalizationKey.commonOk.localized) {
                    dismiss()
                }
            } message: {
                Text(LocalizationKey.profileUpdated.localized)
            }
            .onAppear {
                // 更新 ViewModel 中的 currentUser（如果 appState 中的用户信息更新了）
                if viewModel.currentUser?.id != appState.currentUser?.id {
                    viewModel.currentUser = appState.currentUser
                    viewModel.loadCurrentProfile()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var avatarSection: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 16, x: 0, y: 8)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 114, height: 114)
                
                AvatarView(
                    urlString: viewModel.avatar.isEmpty ? nil : viewModel.avatar,
                    size: 110,
                    placeholder: Image(systemName: "person.fill")
                )
                
                // 编辑按钮
                Button {
                    viewModel.showAvatarPicker = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .offset(x: 40, y: 40)
            }
            
            Text(LocalizationKey.profileClickToChangeAvatar.localized)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, AppSpacing.xl)
        .sheet(isPresented: $viewModel.showAvatarPicker) {
            AvatarPickerView(selectedAvatar: $viewModel.avatar, currentAvatar: viewModel.avatar)
        }
    }
    
    private var formContent: some View {
        VStack(spacing: AppSpacing.lg) {
            nameField
            emailField
            phoneField
            
            if let errorMessage = viewModel.errorMessage {
                errorMessageView(errorMessage)
            }
            
            saveButton
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, AppSpacing.md)
    }
    
    private var nameField: some View {
        EnhancedTextField(
            title: LocalizationKey.profileName.localized,
            placeholder: LocalizationKey.profileEnterName.localized,
            text: $viewModel.name,
            icon: "person.fill",
            errorMessage: nil
        )
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                EnhancedTextField(
                                    title: LocalizationKey.profileEmail.localized,
                                    placeholder: appState.currentUser?.email == nil ? LocalizationKey.profileEnterEmail.localized : LocalizationKey.profileEnterNewEmail.localized,
                                    text: $viewModel.email,
                                    icon: "envelope.fill",
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress,
                                    autocapitalization: .never,
                                    errorMessage: nil
                                )
                                
                                if viewModel.showEmailCodeField {
                                    HStack(spacing: AppSpacing.sm) {
                                        EnhancedTextField(
                                            title: LocalizationKey.profileVerificationCode.localized,
                                            placeholder: LocalizationKey.profileEnterVerificationCode.localized,
                                            text: $viewModel.emailVerificationCode,
                                            icon: "key.fill",
                                            keyboardType: .numberPad,
                                            errorMessage: nil
                                        )
                                        
                                        Button {
                                            viewModel.sendEmailUpdateCode()
                                        } label: {
                                            if viewModel.isSendingEmailCode {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                            } else {
                                                Text(viewModel.emailCountdown > 0 ? String(format: LocalizationKey.authCountdownSeconds.localized, viewModel.emailCountdown) : LocalizationKey.authSendCode.localized)
                                                    .font(AppTypography.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .frame(width: 100)
                                        .frame(height: 52)
                                        .foregroundColor(viewModel.emailCountdown > 0 ? AppColors.textSecondary : AppColors.primary)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(viewModel.emailCountdown > 0 ? AppColors.cardBackground : AppColors.primary.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .stroke(viewModel.emailCountdown > 0 ? AppColors.separator.opacity(0.2) : AppColors.primary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .disabled(viewModel.isSendingEmailCode || viewModel.emailCountdown > 0 || viewModel.email.isEmpty || viewModel.email == (appState.currentUser?.email ?? ""))
                                    }
                                } else if viewModel.email != (appState.currentUser?.email ?? "") && !viewModel.email.isEmpty {
                                    Button {
                                        viewModel.showEmailCodeField = true
                                    } label: {
                                        Text(LocalizationKey.authSendCode.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
        }
    }
    
    private var phoneField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                EnhancedTextField(
                                    title: LocalizationKey.profilePhone.localized,
                                    placeholder: appState.currentUser?.phone == nil ? LocalizationKey.profileEnterPhone.localized : LocalizationKey.profileEnterNewPhone.localized,
                                    text: $viewModel.phone,
                                    icon: "phone.fill",
                                    keyboardType: .phonePad,
                                    textContentType: .telephoneNumber,
                                    errorMessage: nil
                                )
                                
                                if viewModel.showPhoneCodeField {
                                    HStack(spacing: AppSpacing.sm) {
                                        EnhancedTextField(
                                            title: LocalizationKey.profileVerificationCode.localized,
                                            placeholder: LocalizationKey.profileEnterVerificationCode.localized,
                                            text: $viewModel.phoneVerificationCode,
                                            icon: "key.fill",
                                            keyboardType: .numberPad,
                                            errorMessage: nil
                                        )
                                        
                                        Button {
                                            viewModel.sendPhoneUpdateCode()
                                        } label: {
                                            if viewModel.isSendingPhoneCode {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                            } else {
                                                Text(viewModel.phoneCountdown > 0 ? String(format: LocalizationKey.authCountdownSeconds.localized, viewModel.phoneCountdown) : LocalizationKey.authSendCode.localized)
                                                    .font(AppTypography.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .frame(width: 100)
                                        .frame(height: 52)
                                        .foregroundColor(viewModel.phoneCountdown > 0 ? AppColors.textSecondary : AppColors.primary)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(viewModel.phoneCountdown > 0 ? AppColors.cardBackground : AppColors.primary.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .stroke(viewModel.phoneCountdown > 0 ? AppColors.separator.opacity(0.2) : AppColors.primary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .disabled(viewModel.isSendingPhoneCode || viewModel.phoneCountdown > 0 || viewModel.phone.isEmpty || viewModel.phone == (appState.currentUser?.phone ?? ""))
                                    }
                                } else if viewModel.phone != (appState.currentUser?.phone ?? "") && !viewModel.phone.isEmpty {
                                    Button {
                                        viewModel.showPhoneCodeField = true
                                    } label: {
                                        Text(LocalizationKey.authSendCode.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
        }
    }
    
    private func errorMessageView(_ errorMessage: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.error)
            Text(errorMessage)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.error)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var saveButton: some View {
        Button {
            viewModel.saveProfile { updatedUser in
                if let updatedUser = updatedUser {
                    appState.currentUser = updatedUser
                }
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(LocalizationKey.commonSave.localized)
                        .font(AppTypography.bodyBold)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.white)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: AppColors.gradientPrimary),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 56))
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.5 : 1.0)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

