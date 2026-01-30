import SwiftUI
import AVKit
import AVFoundation

/// 自定义视频播放器视图类
class VideoPlayerUIView: UIView {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var loopObserver: NSObjectProtocol?
    var isLooping: Bool = true
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 确保 playerLayer 的 frame 始终与视图的 bounds 一致
        playerLayer?.frame = bounds
    }
    
    func setupPlayer(url: URL, isLooping: Bool, isMuted: Bool) {
        // 清理旧的播放器
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        
        // 创建新的播放器
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = isMuted
        
        let newPlayerLayer = AVPlayerLayer(player: newPlayer)
        newPlayerLayer.videoGravity = .resizeAspectFill
        newPlayerLayer.frame = bounds
        
        layer.addSublayer(newPlayerLayer)
        
        player = newPlayer
        playerLayer = newPlayerLayer
        self.isLooping = isLooping
        
        // 设置循环播放
        if isLooping {
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, let player = self.player else { return }
                player.seek(to: .zero)
                player.play()
            }
        }
        
        newPlayer.play()
    }
    
    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
}

/// 视频播放器视图，用于加载界面
struct VideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    var isLooping: Bool = true
    var isMuted: Bool = true
    
    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.backgroundColor = .clear
        
        // 尝试从 Bundle 加载视频（推荐方式，需要文件添加到 Xcode 项目）
        var url: URL?
        
        // 方法1: 从 Bundle 加载（文件需要添加到 Xcode 项目中）
        if let bundleURL = Bundle.main.url(forResource: videoName, withExtension: videoExtension) {
            url = bundleURL
        } else if let documentsPath = Bundle.main.resourcePath {
            let filePath = (documentsPath as NSString).appendingPathComponent("\(videoName).\(videoExtension)")
            if FileManager.default.fileExists(atPath: filePath) {
                url = URL(fileURLWithPath: filePath)
            }
        }
        // 方法3: 尝试从项目根目录加载（开发时备用方案）
        else {
            let projectPath = Bundle.main.bundlePath
            let possiblePaths = [
                (projectPath as NSString).appendingPathComponent("\(videoName).\(videoExtension)"),
                (projectPath as NSString).appendingPathComponent("../\(videoName).\(videoExtension)"),
                (projectPath as NSString).appendingPathComponent("../../\(videoName).\(videoExtension)")
            ]
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    url = URL(fileURLWithPath: path)
                    break
                }
            }
        }
        
        guard let videoURL = url else {
            return view
        }
        
        // 设置播放器
        view.setupPlayer(url: videoURL, isLooping: isLooping, isMuted: isMuted)
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
        // updateUIView 会在布局更新时调用，但 frame 更新由 layoutSubviews 处理
        // 这里不需要做任何操作，因为 layoutSubviews 会自动更新 frame
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        // Coordinator 现在主要用于兼容性，实际逻辑在 VideoPlayerUIView 中
    }
}

/// 全屏视频加载视图
struct VideoLoadingView: View {
    var videoName: String = "linker"
    var videoExtension: String = "mp4"
    var videoNames: [String]? = nil  // 多个视频文件名（不含扩展名），如果提供则随机选择
    var showOverlay: Bool = true
    @State private var selectedVideoName: String
    
    init(videoName: String = "linker", videoExtension: String = "mp4", videoNames: [String]? = nil, showOverlay: Bool = true) {
        self.videoName = videoName
        self.videoExtension = videoExtension
        self.videoNames = videoNames
        self.showOverlay = showOverlay
        
        // 如果有多个视频，随机选择一个；否则使用默认的 videoName
        if let videoNames = videoNames, !videoNames.isEmpty {
            self._selectedVideoName = State(initialValue: videoNames.randomElement() ?? videoName)
        } else {
            self._selectedVideoName = State(initialValue: videoName)
        }
    }
    
    var body: some View {
        ZStack {
            // 视频背景
            VideoPlayerView(
                videoName: selectedVideoName,
                videoExtension: videoExtension,
                isLooping: true,
                isMuted: true
            )
            .ignoresSafeArea()
            
            // 可选的半透明遮罩（如果需要）
            if showOverlay {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // 每次视图出现时，如果有多个视频，重新随机选择
            if let videoNames = videoNames, !videoNames.isEmpty {
                selectedVideoName = videoNames.randomElement() ?? videoName
            }
        }
    }
}

