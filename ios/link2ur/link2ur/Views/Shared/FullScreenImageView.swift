import SwiftUI

// 全屏图片查看器 - 类似小红书风格
struct FullScreenImageView: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .ignoresSafeArea()
                .opacity(0.98)
            
            // 图片轮播
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                    ImageViewWithGestures(
                        imageUrl: imageUrl,
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        onSingleTap: {
                            // 单击切换控制栏显示
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls.toggle()
                            }
                        }
                    )
                    .background(Color.black)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: selectedIndex) { _ in
                // 切换图片时重置缩放和偏移
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    lastScale = 1.0
                }
            }
            
            // 顶部关闭按钮（始终可见，避免用户单击图片后找不到关闭入口）
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 36, height: 36)
                            )
                    }
                    .padding(.trailing, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
                Spacer()
            }
            
            // 底部图片指示器（如果有多张图片，可隐藏）
            if images.count > 1 && showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(selectedIndex + 1) / \(images.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                        Spacer()
                    }
                    .padding(.bottom, AppSpacing.lg)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .statusBarHidden()
        .onAppear {
            // 重置状态
            scale = 1.0
            offset = .zero
            lastOffset = .zero
            lastScale = 1.0
            showControls = true
        }
    }
}

// 带手势的图片视图
struct ImageViewWithGestures: View {
    let imageUrl: String
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let onSingleTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let w = max(1, geometry.size.width)
            let h = max(1, geometry.size.height)
            // 使用 AsyncImageView（与气泡一致），走 ImageCache，可正确加载私密图 URL（含 token）
            // placeholderBackground: .black 避免 .fit 时两侧/上下留白露出浅色“容器”
            AsyncImageView(
                urlString: imageUrl,
                placeholder: Image(systemName: "photo"),
                width: w,
                height: h,
                contentMode: .fit,
                cornerRadius: 0,
                placeholderBackground: .black
            )
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: w, height: h)
            .clipped()
            .gesture(
                // 双击缩放
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
            )
            .simultaneousGesture(
                // 单击切换控制栏（多图时底部页指示显隐）
                TapGesture(count: 1)
                    .onEnded {
                        onSingleTap()
                    }
            )
            .simultaneousGesture(
                // 捏合缩放
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        let newScale = scale * delta
                        scale = min(max(newScale, 1.0), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale < 1.0 {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                // 拖拽（仅在缩放时可用）
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
        }
    }
}

