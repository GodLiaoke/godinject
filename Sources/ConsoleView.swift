import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════
//  ConsoleView — 主界面
//  完全用 PhoenixTheme 的令牌与组件（PhoenixBackground / SignalLamp /
//  PhoenixMark / PhoenixType / PhoenixStatus）
// ═══════════════════════════════════════════════════════════════

struct StatusRow: Identifiable {
    let id = UUID()
    var name: String
    var level: SignalLamp.Level
    var value: String
}

struct ConsoleView: View {
    @EnvironmentObject private var model: AppModel

    @State private var rows: [StatusRow] = [
        StatusRow(name: "授权状态", level: .go, value: "已验证"),
        StatusRow(name: "沙盒访问", level: .waiting, value: "未检查"),
        StatusRow(name: "App Group", level: .waiting, value: "未检查"),
        StatusRow(name: "游戏容器", level: .waiting, value: "未检查"),
    ]
    @State private var logs: [String] = []
    @State private var busy = false
    @State private var container: String?

    private let pageMargin: CGFloat = 18
    private let sectionGap: CGFloat = 14

    var body: some View {
        ZStack {
            PhoenixBackground()
            VStack(spacing: 0) {
                header
                Divider().overlay(PhoenixTheme.hairline)
                ScrollView {
                    VStack(spacing: sectionGap) {
                        statusPanel
                        logPanel
                    }
                    .padding(.horizontal, pageMargin)
                    .padding(.vertical, sectionGap)
                }
                bottomBar
            }
        }
    }

    // MARK: 顶栏（品牌 + 构建标识，不滚动）

    private var header: some View {
        HStack(spacing: 10) {
            PhoenixMark(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("God全系统")
                    .font(PhoenixType.section)
                    .foregroundStyle(PhoenixTheme.text)
                Text(BuildInfo.shortLine)
                    .font(PhoenixType.monoSmall)
                    .foregroundStyle(PhoenixTheme.muted)
            }
            Spacer()
            Button {
                model.signOut()
            } label: {
                Text("退出")
                    .font(PhoenixType.captionStrong)
                    .foregroundStyle(PhoenixTheme.muted)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .glassCapsule()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, pageMargin)
        .padding(.vertical, 10)
    }

    // MARK: 状态面板

    private var statusPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 10) {
                    SignalLamp(level: row.level)
                    Text(row.name)
                        .font(PhoenixType.body)
                        .foregroundStyle(PhoenixTheme.text)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .font(PhoenixType.mono)
                        .foregroundStyle(row.level == .fault
                                         ? PhoenixStatus.offline
                                         : PhoenixTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(minHeight: 44)
                .padding(.horizontal, pageMargin)

                if idx != rows.count - 1 {
                    Divider().overlay(PhoenixTheme.hairline)
                        .padding(.leading, pageMargin)
                }
            }
        }
        .glassPanelElevated(cornerRadius: 18)
    }

    // MARK: 日志面板

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(PhoenixType.monoSmall)
                                .foregroundStyle(PhoenixTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(pageMargin)
                }
                .frame(height: 200)
                .onChange(of: logs.count) { _, n in
                    guard n > 0 else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(n - 1, anchor: .bottom)
                    }
                }
            }
        }
        .glassPanelElevated(cornerRadius: 18)
    }

    // MARK: 底栏（不滚动）

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(PhoenixTheme.hairline)
            HStack(spacing: 10) {
                Button {
                    Task { await runInit() }
                } label: {
                    Text("初始化")
                        .font(PhoenixType.section)
                        .foregroundStyle(PhoenixTheme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .opacity(busy ? 0.45 : 1)

                Button {
                    Task { await runInject() }
                } label: {
                    Text("开始注入")
                        .font(PhoenixType.section)
                        .foregroundStyle(PhoenixTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(PhoenixTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .opacity(busy ? 0.45 : 1)
            }
            .padding(.horizontal, pageMargin)
            .padding(.vertical, 14)
        }
    }

    // MARK: 动作

    private func log(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logs.append("\(f.string(from: Date()))  \(s)")
    }

    private func setRow(_ idx: Int, level: SignalLamp.Level, value: String) {
        guard idx < rows.count else { return }
        rows[idx].level = level
        rows[idx].value = value
    }

    private func runInit() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        log("检查环境…")
        setRow(1, level: .waiting, value: "检查中…")

        let (ok, count, found, gok) = await withCheckedContinuation { (cont: CheckedContinuation<(Bool, Int, String?, Bool), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let g = wq_app_group()
                let probe = "/var/mobile/Containers/Data/Application"
                var st = stat()
                let canStat = wq_stat(probe, &st) && (st.st_mode & S_IFMT) == S_IFDIR
                let list = canStat ? (wq_enumerate(probe, 0, nil, nil) as? [String] ?? []) : []
                var found: String? = nil
                for d in list {
                    if let label = wq_container_label(d), label == "com.tencent.tmgp.dfm" {
                        found = d
                        break
                    }
                }
                cont.resume(returning: (list.count > 0, list.count, found, g != nil))
            }
        }

        setRow(1, level: ok ? .go : .fault, value: ok ? "\(count) 项" : "不可用")
        setRow(2, level: gok ? .go : .fault, value: gok ? "已获取" : "缺失")
        setRow(3, level: found != nil ? .go : .waiting, value: found != nil ? "已定位" : "未找到")
        self.container = found
        log(ok ? "沙盒可用（\(count) 项）" : "沙盒不可用，检查签名 entitlement")
        if let f = found { log(f) }
    }

    private func runInject() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let card = model.card
        guard !card.isEmpty else {
            log("无卡密记录")
            return
        }
        log("开始注入…")

        // 容器
        var c = container
        if c == nil {
            let list = (wq_enumerate("/var/mobile/Containers/Data/Application", 0, nil, nil) as? [String]) ?? []
            for d in list {
                if let label = wq_container_label(d), label == "com.tencent.tmgp.dfm" {
                    c = d
                    break
                }
            }
        }
        guard let base = c else {
            log("未找到游戏容器")
            setRow(3, level: .fault, value: "未找到")
            return
        }
        container = base

        // 逐级建目录
        var cur = base
        for p in ["Documents", "DeltaForce", "Saved", "LuaDebug",
                  "LuaSource", "DFM", "BusinessEntrance"] {
            cur = (cur as NSString).appendingPathComponent(p)
            var st = stat()
            if wq_stat(cur, &st) && (st.st_mode & S_IFMT) == S_IFDIR { continue }
            if !wq_create_dir(cur, nil) {
                log("建目录失败：\(p)")
                return
            }
        }

        // 下载（带卡密）
        let enc = card.addingPercentEncoding(withAllowedCharacters: .init(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? card
        guard let url = URL(string: "\(AppModel.serverBase)\(AppModel.downloadPath)?card=\(enc)") else {
            log("地址无效")
            return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("GODInject/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200, data.count > 100,
                  Array(data.prefix(4)) == [0x1b, 0x4c, 0x75, 0x61] else {
                if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let e = j["error"] as? String {
                    log("下载失败：\(AppModel.humanReadable(e))")
                } else {
                    log("下载失败：HTTP \(code)")
                }
                return
            }

            let dest = (cur as NSString).appendingPathComponent("EntranceFlow.lua")
            var st = stat()
            if wq_stat(dest, &st) {
                if let old = wq_read(dest, 0, nil) as Data? {
                    wq_write(dest + ".bak", old, nil)
                }
            }
            let ok = wq_stat(dest, &st) ? wq_write(dest, data, nil) : wq_create_file(dest, data, nil)
            log(ok ? "写入成功 \(data.count / 1024) KB" : "写入失败")
        } catch {
            log("网络：\(error.localizedDescription)")
        }
    }
}
