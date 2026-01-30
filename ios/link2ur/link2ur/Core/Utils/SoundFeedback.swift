import AVFoundation
import AudioToolbox

/// 音效反馈 - 操作成功/失败提示音，尊重静音开关与用户设置
public enum SoundFeedback {

    private static let successSoundEnabledKey = "success_sound_enabled"

    /// 用户是否开启成功提示音（默认开启）
    public static var isSuccessSoundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: successSoundEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: successSoundEnabledKey) }
    }

    /// 播放成功提示音（仅在开启且未静音时播放）
    public static func success() {
        guard isSuccessSoundEnabled else { return }
        DispatchQueue.main.async {
            playSystemSoundIfNotMuted(1057) // 短促成功音
        }
    }

    /// 播放错误提示音
    public static func error() {
        guard isSuccessSoundEnabled else { return }
        DispatchQueue.main.async {
            playSystemSoundIfNotMuted(1073) // 短促结束音
        }
    }

    /// 在未静音时播放系统音（使用 .ambient 类别会随静音开关静音）
    private static func playSystemSoundIfNotMuted(_ soundID: SystemSoundID) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            AudioServicesPlaySystemSound(soundID)
        } catch {
            // 权限或配置失败时静默跳过
        }
    }
}
