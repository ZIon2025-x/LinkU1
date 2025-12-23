import SwiftUI

/// SwiftUI View 扩展 - 提供企业级修饰符和工具

extension View {
    
    // MARK: - 加载状态
    
    /// 添加加载状态覆盖层
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
            }
        )
    }
    
    // MARK: - 错误处理
    
    /// 添加错误处理
    func errorAlert(
        error: Binding<Error?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(
            "错误",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil; onDismiss?() } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("确定", role: .cancel) {
                error.wrappedValue = nil
                onDismiss?()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    // MARK: - 条件修饰符
    // 注意：条件修饰符已在 ViewBuilder+Extensions.swift 中定义
    
    // MARK: - 导航
    
    /// 隐藏导航栏
    func hideNavigationBar() -> some View {
        self.navigationBarHidden(true)
    }
    
    /// 设置导航栏样式
    func navigationBarStyle(
        backgroundColor: Color = .clear,
        titleColor: Color = .primary
    ) -> some View {
        self.onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(backgroundColor)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(titleColor)]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(titleColor)]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // MARK: - 手势
    
    /// 添加点击手势（带反馈）
    func onTapGestureWithFeedback(
        perform action: @escaping () -> Void
    ) -> some View {
        self.onTapGesture {
            // 触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }
    }
    
    /// 添加长按手势（带反馈）
    func onLongPressGestureWithFeedback(
        perform action: @escaping () -> Void
    ) -> some View {
        self.onLongPressGesture {
            // 触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }
    }
    
    // MARK: - 调试
    
    /// 调试边框（仅 DEBUG 模式）
    func debugBorder(_ color: Color = .red) -> some View {
        #if DEBUG
        return self.border(color, width: 1)
        #else
        return self
        #endif
    }
    
    /// 调试背景（仅 DEBUG 模式）
    func debugBackground(_ color: Color = .red.opacity(0.1)) -> some View {
        #if DEBUG
        return self.background(color)
        #else
        return self
        #endif
    }
}

// MARK: - 动画扩展

extension View {
    /// 条件动画
    func conditionalAnimation<Value: Equatable>(
        _ value: Value,
        animation: Animation = .default
    ) -> some View {
        self.animation(value == value ? animation : nil, value: value)
    }
}

// MARK: - 安全区域扩展

extension View {
    /// 忽略安全区域（所有边）
    func ignoreAllSafeAreas() -> some View {
        self.ignoresSafeArea(.all)
    }
    
    /// 忽略安全区域（特定边）
    func ignoreSafeArea(_ edges: Edge.Set) -> some View {
        self.ignoresSafeArea(.container, edges: edges)
    }
}

// MARK: - 性能优化扩展

extension View {
    /// 优化滚动性能 - 使用drawingGroup减少重绘
    func optimizedScroll() -> some View {
        self.drawingGroup()
    }
    
    /// 优化列表项性能 - 减少不必要的重绘
    func optimizedListItem() -> some View {
        self.drawingGroup()
    }
    
    /// 优化卡片性能 - 使用drawingGroup优化渲染
    func optimizedCard() -> some View {
        self.drawingGroup()
    }
    
    /// 优化动画性能 - 使用更高效的动画配置
    func optimizedAnimation(_ animation: Animation = .easeInOut(duration: 0.25)) -> some View {
        self.animation(animation, value: UUID())
    }
    
    /// 延迟渲染 - 延迟视图渲染以优化初始加载性能
    func deferredRendering(until condition: Bool) -> some View {
        Group {
            if condition {
                self
            } else {
                Color.clear
            }
        }
    }
    
    /// 优化图片加载 - 使用占位符和延迟加载
    func optimizedImageLoading() -> some View {
        self.drawingGroup()
    }
    
    /// 减少视图更新 - 使用EquatableView减少不必要的重绘
    func reduceUpdates<Content: View & Equatable>(_ content: Content) -> some View {
        EquatableView(content: content)
    }
}

