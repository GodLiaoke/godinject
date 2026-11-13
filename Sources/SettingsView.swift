import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════
//  SettingsView — 设置
//   · 清理残留数据（连我们创建的 BusinessEntrance 目录一起删）
//   · 退出登录
//   · 构建信息
// ═══════════════════════════════════════════════════════════════

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var busy = false
    @State private var message: String?
    @State private var showCleanConfirm = false
    @State private var showSignOutConfirm = false
    @State private var lastCleanResult: String?

    private let pageMargin: CGFloat = 18

    var body: some View {
        ZStack {
            PhoenixBackground()
            ScrollView {
                VStack(spacing: 14) {

                    // 维护
                    section("维护") {
                        actionRow(
                            title: "清理残留数据",
                            subtitle: "删除已写入的 lua 和创建的整条目录",
                            tint: PhoenixStatus.offline
                        ) {
                            showCleanConfirm = true
                        }
                        Divider().overlay(PhoenixTheme.hairline)
                        infoRow(title: "说明",
                                value: "只清理游戏沙盒里本工具创建的目录")
                    }

                    // 账户
                    section("账户") {
                        actionRow(
                            title: "退出登录",
                            subtitle: "清除本机保存的卡密，回到激活页",
                            tint: PhoenixStatus.offline
                        ) {
                            showSignOutConfirm = true
                        }
                    }

                    // 关于
                    section("关于") {
                        infoRow(title: "版本", value: BuildInfo.shortLine)
                        Divider().overlay(PhoenixTheme.hairline)
                        infoRow(title: "服务器", value: AppModel.serverBase)
                    }

                    if let m = message {
                        Text(m)
                            .font(PhoenixType.caption)
                            .foregroundStyle(PhoenixTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, pageMargin)
                    }
                }
                .padding(.horizontal, pageMargin)
                .padding(.vertical, 14)
            }
            if busy {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView().controlSize(.large)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .font(PhoenixType.section)
                    .foregroundStyle(PhoenixTheme.accent)
            }
        }
        .confirmationDialog("清理残留数据？",
                            isPresented: $showCleanConfirm,
                            titleVisibility: .visible) {
            Button("清理", role: .destructive) { Task { await clean() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会删除游戏目录里 BusinessEntrance 整个文件夹（含 EntranceFlow.lua 和备份）")
        }
        .confirmationDialog("退出登录？",
                            isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                model.signOut()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本机保存的卡密会被清除，需要重新验证")
        }
    }

    // MARK: 组件

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PhoenixType.caption)
                .foregroundStyle(PhoenixTheme.muted)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .glassPanelElevated(cornerRadius: 18)
        }
    }

    private func actionRow(title: String, subtitle: String, tint: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PhoenixType.section)
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(PhoenixType.caption)
                        .foregroundStyle(PhoenixTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PhoenixTheme.muted.opacity(0.6))
            }
            .frame(minHeight: 56)
            .padding(.horizontal, pageMargin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(PhoenixType.body)
                .foregroundStyle(PhoenixTheme.text)
            Spacer(minLength: 12)
            Text(value)
                .font(PhoenixType.mono)
                .foregroundStyle(PhoenixTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, pageMargin)
    }

    // MARK: 清理

    private func clean() async {
        busy = true
        message = nil
        defer { busy = false }

        let r = await Task.detached(priority: .userInitiated) { () -> String in
            guard let base = GODPaths.gameContainer() else {
                return "未找到游戏容器"
            }
            let root = GODPaths.businessEntrance(in: base)
            var st = stat()
            if !wq_stat(root, &st) {
                return "没有可清理的数据"
            }
            // 整条目录一起删
            if wq_delete_tree(root, nil) {
                return "已清理：BusinessEntrance"
            }
            // 退一步：只删里面的文件
            var removed = 0
            if let items = wq_list(root, nil) as? [String] {
                for f in items {
                    let p = (root as NSString).appendingPathComponent(f)
                    if wq_delete(p, nil) { removed += 1 }
                }
            }
            return removed > 0 ? "已删除 \(removed) 个文件" : "清理失败"
        }.value

        message = r
    }
}

// ═══════════════════════════════════════════════════════════════
//  GODPaths — 路径与删除工具（ConsoleView / SettingsView 共用）
// ═══════════════════════════════════════════════════════════════

enum GODPaths {
    static let bundleID = "com.tencent.tmgp.dfm"

    /// 找游戏的数据容器（已缓存在 UserDefaults）
    static func gameContainer() -> String? {
        if let cached = UserDefaults.standard.string(forKey: "god.container") {
            var st = stat()
            if wq_stat(cached, &st) && (st.st_mode & S_IFMT) == S_IFDIR {
                return cached
            }
        }
        let list = (wq_enumerate("/var/mobile/Containers/Data/Application", 0, nil, nil) as? [String]) ?? []
        for d in list {
            if let label = wq_container_label(d), label == bundleID {
                UserDefaults.standard.set(d, forKey: "god.container")
                return d
            }
        }
        return nil
    }

    /// Documents/DeltaForce/Saved/LuaDebug/LuaSource/DFM/BusinessEntrance
    static func businessEntrance(in container: String) -> String {
        var p = container
        for c in ["Documents", "DeltaForce", "Saved", "LuaDebug",
                  "LuaSource", "DFM", "BusinessEntrance"] {
            p = (p as NSString).appendingPathComponent(c)
        }
        return p
    }

    /// 只删 lua（和它的 .bak），目录保留
    @discardableResult
    static func deleteLuaOnly() -> String {
        guard let base = gameContainer() else { return "未找到游戏容器" }
        let dir = businessEntrance(in: base)
        let lua = (dir as NSString).appendingPathComponent("EntranceFlow.lua")
        let bak = lua + ".bak"
        var removed = 0
        var st = stat()
        if wq_stat(lua, &st) {
            if wq_delete(lua, nil) { removed += 1 }
        }
        st = stat()
        if wq_stat(bak, &st) {
            if wq_delete(bak, nil) { removed += 1 }
        }
        if removed == 0 { return "没有可删除的 lua" }
        return "已删除 EntranceFlow.lua" + (removed > 1 ? " 和备份" : "")
    }

    /// 目录是否存在
    static func luaExists() -> Bool {
        guard let base = gameContainer() else { return false }
        let lua = (businessEntrance(in: base) as NSString).appendingPathComponent("EntranceFlow.lua")
        var st = stat()
        return wq_stat(lua, &st)
    }
}
