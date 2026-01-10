import SwiftUI

/// 分享图预览和分享面板
struct ImageShareSheet: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    @State private var showSystemShare = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 图片预览
                ScrollView {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                
                Divider()
                
                // 操作按钮
                VStack(spacing: AppSpacing.md) {
                    Button(action: {
                        showSystemShare = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(LocalizationKey.shareShareImage.localized)
                        }
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.primary)
                        .cornerRadius(AppCornerRadius.large)
                    }
                    
                    Button(action: {
                        saveToPhotos()
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(LocalizationKey.shareSaveToPhotos.localized)
                        }
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppCornerRadius.large)
                    }
                }
                .padding(AppSpacing.md)
            }
            .navigationTitle(LocalizationKey.shareImage.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.commonDone.localized) {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                ShareSheet(items: [image])
            }
        }
    }
    
    private func saveToPhotos() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        HapticFeedback.success()
    }
}
