import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════
//  AppModel — LicenseView 依赖的最小模型
//  激活 = 向服务器换取注入文件（下载成功即验证通过）
// ═══════════════════════════════════════════════════════════════

@MainActor
final class AppModel: ObservableObject {
    @Published var activating = false
    @Published var activationNote: String?
    @Published var errorMessage: String?
    @Published var licensed: Bool =
        UserDefaults.standard.bool(forKey: "god.licensed")
    @Published var card: String =
        UserDefaults.standard.string(forKey: "god.card") ?? ""

    static let serverBase = "https://ios.ouovo.cc"
    static let downloadPath = "/api/god/download"

    func activate(card raw: String) async {
        activating = true
        activationNote = "校验卡密"
        errorMessage = nil
        ActivationReporter.shared.update("校验卡密")
        defer {
            activating = false
            activationNote = nil
            ActivationReporter.shared.reset()
        }

        let enc = raw.addingPercentEncoding(
            withAllowedCharacters: .init(charactersIn:
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))
            ?? raw
        guard let url = URL(string: "\(Self.serverBase)\(Self.downloadPath)?card=\(enc)") else {
            errorMessage = "地址无效"
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("GODInject/1.0", forHTTPHeaderField: "User-Agent")

        do {
            activationNote = "下载模块"
            ActivationReporter.shared.update("下载模块")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0

            if code == 200, data.count > 100 {
                let b = [UInt8](data.prefix(4))
                if b == [0x1b, 0x4c, 0x75, 0x61] {   // \x1bLua
                    let dst = FileManager.default.temporaryDirectory
                        .appendingPathComponent("god.lua")
                    try? data.write(to: dst)
                    UserDefaults.standard.set(raw, forKey: "god.card")
                    UserDefaults.standard.set(true, forKey: "god.licensed")
                    self.card = raw
                    licensed = true
                    return
                }
            }

            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let e = j["error"] as? String {
                errorMessage = Self.humanReadable(e)
            } else {
                errorMessage = "HTTP \(code)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func humanReadable(_ e: String) -> String {
        switch e {
        case "card_not_found": return "卡密不存在"
        case "card_revoked":   return "卡密已被封禁"
        case "card_expired":   return "卡密已过期"
        case "card_format":    return "卡密格式不正确"
        case "no_file":        return "服务器缺少模块文件"
        default:               return e
        }
    }

    func signOut() {
        UserDefaults.standard.set(false, forKey: "god.licensed")
        licensed = false
    }
}

// ═══════════════════════════════════════════════════════════════
//  两个玻璃修饰符（LicenseView 用到，Phoenix 原实现不在公开源码里）
// ═══════════════════════════════════════════════════════════════

struct GlassPanelElevated: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // 白色液态玻璃：半透明白 + 顶部高光 + 底部暗边
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(PhoenixTheme.panel)
                            .overlay {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), .clear, Color.black.opacity(0.04)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
            }
    }
}

struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(PhoenixTheme.hairline, lineWidth: 1) }
    }
}

extension View {
    func glassPanelElevated(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassPanelElevated(cornerRadius: cornerRadius))
    }
    func glassCapsule() -> some View {
        modifier(GlassCapsule())
    }
}
