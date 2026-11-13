import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════
//  GODApp — 入口
//  已授权 → 控制台；未授权 → LicenseView（Phoenix 原样）
// ═══════════════════════════════════════════════════════════════

@main
struct GODApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.licensed {
                ConsoleView()
            } else {
                LicenseView()
            }
        }
    }
}
