import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConfirmOperation: Identifiable {
    let id = UUID()
    let action: String
    let title: String
    let message: String
    let fields: [String: Any]
    var destructive = false
}
struct ConfirmOperationModifier: ViewModifier {
    @ObservedObject var model: ConsoleModel
    @Binding var request: ConfirmOperation?
    func body(content: Content) -> some View {
        content.alert(item: $request) { item in
            let execute = {
                if item.action == "restart-service" || item.action == "stop-service" { model.serviceAction(item.action) }
                else { var fields = item.fields; fields["confirmed"] = true; model.command(item.action, fields: fields) }
            }
            return Alert(title: Text(item.title), message: Text(item.message), primaryButton: item.destructive ? .destructive(Text("确认执行"), action: execute) : .default(Text("确认执行"), action: execute), secondaryButton: .cancel(Text("取消")))
        }
    }
}
@MainActor
enum FileChooser {
    static func open(_ title: String, types: [UTType] = [], hidden: Bool = false, then: @escaping (String) -> Void) {
        let panel = NSOpenPanel(); panel.title = title; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.showsHiddenFiles = hidden
        if !types.isEmpty { panel.allowedContentTypes = types }
        panel.begin { response in if response == .OK, let url = panel.url { then(url.path) } }
    }
    static func save(_ title: String, name: String, then: @escaping (String) -> Void) {
        let panel = NSSavePanel(); panel.title = title; panel.nameFieldStringValue = name
        panel.begin { response in if response == .OK, let url = panel.url { then(url.path) } }
    }
}
struct RawJSONView: View {
    let title: String
    let value: JSONValue?
    var body: some View {
        if let value {
            DisclosureGroup(title) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Spacer(); Button("复制 JSON") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value.pretty, forType: .string) } }
                    ScrollView([.horizontal, .vertical]) { Text(value.pretty).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 320)
                }.padding(.top, 8)
            }
        }
    }
}
struct ActionResultView: View {
    @ObservedObject var model: ConsoleModel
    let actions: [String]
    let title: String
    var body: some View {
        let results = actions.filter { model.results[$0] != nil }
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 16, weight: .semibold))
                ForEach(results, id: \.self) { action in
                    if let value = model.results[action] {
                        if let message = value["message"] { Text(message.text).font(.system(size: 13)).textSelection(.enabled) }
                        if let phase = value["phase"] { Text("阶段：\(phase.text)").font(.system(size: 12)).foregroundStyle(.secondary) }
                        if let error = value["error"] { notice(error.text, symbol: "exclamationmark.circle", color: .orange) }
                        if let info = value["info"] {
                            ResultFieldsView(value: info, fields: [("id", "设备 ID"), ("version", "发现协议"), ("state", "网络状态码"), ("ip", "设备 IP"), ("ssid_hash", "SSID 摘要")])
                        }
                        if let checks = value["checks"]?.array, !checks.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(checks.indices, id: \.self) { i in
                                    let check = checks[i]
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(check["status"]?.text ?? "未知").font(.system(size: 11, weight: .semibold)).frame(width: 58, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 4) { Text(check["name"]?.text ?? "检查项").font(.system(size: 13, weight: .medium)); Text(check["detail"]?.text ?? "").font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled) }
                                        Spacer()
                                    }.padding(.vertical, 8); Divider()
                                }
                            }
                        }
                        if let networks = value["networks"]?.array, !networks.isEmpty {
                            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                                GridRow { Text("序号"); Text("网络名称"); Text("密码") }.fontWeight(.medium)
                                ForEach(networks.indices, id: \.self) { i in
                                    let network = networks[i]
                                    GridRow { Text(network["index"]?.text ?? String(i + 1)).monospacedDigit(); Text(network["ssid"]?.text ?? "未知").textSelection(.enabled); Text(network["password_set"]?.text ?? "未知").foregroundStyle(.secondary) }
                                }
                            }.font(.system(size: 13))
                        }
                        if let encoded = value["bytes_base64"]?.text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("读取 \(value["bytes"]?.text ?? "未知") 字节").font(.system(size: 13, weight: .medium))
                                if let text = value["text"]?.text, !text.isEmpty { Text(text).font(.system(size: 13)).textSelection(.enabled) }
                                if let bytes = Data(base64Encoded: encoded) { Text(bytes.map { String(format: "%02x", $0) }.joined(separator: " ")).font(.system(size: 12, design: .monospaced)).textSelection(.enabled) }
                            }
                        }
                        if let path = value["path"] { Text(path.text).font(.system(size: 12)).textSelection(.enabled) }
                        if let path = value["backup_directory"] { Text("备份目录：\(path.text)").font(.system(size: 12)).textSelection(.enabled) }
                        RawJSONView(title: "\(action) 返回数据", value: value)
                    }
                }
            }
        }
    }
}
struct ResultFieldsView: View {
    let value: JSONValue
    let fields: [(String, String)]
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
            ForEach(fields.indices, id: \.self) { i in
                if let v = value[fields[i].0] { GridRow { Text(fields[i].1).foregroundStyle(.secondary); Text(v.text).textSelection(.enabled).monospacedDigit() } }
            }
        }.font(.system(size: 13))
    }
}
struct CapabilityReason: View {
    @ObservedObject var model: ConsoleModel
    let action: String
    var body: some View {
        if let reason = model.capabilityReason(action), !reason.isEmpty {
            Text(reason).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
struct CapabilityListView: View {
    @ObservedObject var model: ConsoleModel
    var body: some View {
        if let capabilities = model.snapshot?.capabilities {
            DisclosureGroup("后台能力清单 · \(capabilities.count) 项") {
                VStack(spacing: 0) {
                    ForEach(capabilities) { capability in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: capability.available ? "checkmark.circle" : "minus.circle").foregroundStyle(capability.available ? good : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(capability.title).font(.system(size: 13, weight: .medium))
                                if let reason = capability.reason, !reason.isEmpty { Text(reason).font(.system(size: 12)).foregroundStyle(.secondary) }
                            }
                            Spacer(); Text(capability.category).font(.system(size: 11)).foregroundStyle(.secondary)
                        }.padding(.vertical, 10)
                        Divider()
                    }
                }.padding(.top, 8)
            }
        }
    }
}
struct DeviceObservationsView: View {
    let value: JSONValue?
    private let fields: [(String, [(String, String)])] = [
        ("运行与目录", [("phase", "运行阶段"), ("selected", "选中 bank"), ("loaded_app", "已加载 bank"), ("loaded", "已加载槽"), ("active", "活动槽"), ("previous", "回退槽"), ("pending", "候选槽"), ("trial_app", "试运行 bank"), ("last_result", "最近结果码"), ("last_switch_source", "最近切换来源"), ("last_switch_target", "最近切换目标"), ("display_completed", "最近事件完成显示"), ("ignored_buttons", "忽略按键次数")]),
        ("内存", [("free_internal_ram", "当前内部 RAM / byte"), ("minimum_free_internal_ram", "最低内部 RAM / byte"), ("free_psram", "当前 PSRAM / byte"), ("minimum_free_psram", "最低 PSRAM / byte"), ("cache_bytes", "应用缓存 / byte")]),
        ("蓝牙通道", [("ble_service_uuid", "应用服务 UUID"), ("ble_service_revision", "服务修订号"), ("ble_characteristics", "特征数量"), ("coc_version", "CoC 协议版本"), ("coc_state", "CoC 状态：0关 / 1等待 / 2连接"), ("coc_psm", "CoC PSM"), ("coc_rx_payload_max", "CoC 接收记录上限 / byte")])
    ]
    var body: some View {
        if let value {
            VStack(alignment: .leading, spacing: 18) {
                Text("完整观测").font(.system(size: 18, weight: .semibold))
                ForEach(fields.indices, id: \.self) { section in
                    DisclosureGroup(fields[section].0) {
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                            ForEach(fields[section].1.indices, id: \.self) { index in
                                let field = fields[section].1[index]
                                if let content = value[field.0] { GridRow { Text(field.1).foregroundStyle(.secondary); Text(content.text).textSelection(.enabled).monospacedDigit() } }
                            }
                        }.font(.system(size: 12)).padding(.top, 12)
                    }
                }
                RawJSONView(title: "全部设备字段", value: value)
            }
        }
    }
}

struct ConnectivityView: View {
    @ObservedObject var model: ConsoleModel
    @State private var deviceID = ""
    @State private var confirmation: ConfirmOperation?
    private var scanned: [JSONValue] { let v = model.results["scan"]; return v?["devices"]?.array ?? v?.array ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button("扫描附近设备") { model.command("scan") }.disabled(model.busy || !model.available("scan"))
                Button("读取鉴权设备信息") { model.command("info") }.disabled(model.busy || !model.available("info"))
                Button("读取完整状态") { model.command("status") }.disabled(model.busy || !model.connected)
            }
            Text("当前配置设备：\(model.snapshot?.deviceId ?? "未读取")").font(.system(size: 14, weight: .medium)).textSelection(.enabled)
            if !scanned.isEmpty {
                VStack(spacing: 0) {
                    ForEach(scanned.indices, id: \.self) { i in
                        let item = scanned[i]
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 5) { Text(item["id"]?.text ?? "未知设备").monospaced(); Text("IP：\(item["ip"]?.text ?? "未提供") · 广播状态：\(item["state"]?.text ?? "未知")").font(.system(size: 12)).foregroundStyle(.secondary) }
                            Spacer(); Button("选择") { deviceID = item["id"]?.text ?? "" }
                        }.padding(.vertical, 13); Divider()
                    }
                }
                Text("扫描结果尚未鉴权；绑定前后台会用已有设备凭据验证身份。").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            GroupBox("设备绑定") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("设备 ID，例如 001122334455", text: $deviceID).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("验证并保存绑定…") { confirmation = .init(action: "bind", title: "保存设备绑定？", message: "使用后台已有凭据验证此设备，并保存独立绑定记录。不会修改私有环境配置。", fields: ["device_id": deviceID]) }.disabled(model.busy || deviceID.isEmpty || !model.available("bind"))
                        Button("解除保存的绑定…", role: .destructive) { confirmation = .init(action: "unbind", title: "解除设备绑定？", message: "删除本机保存的绑定记录。配置中显式指定的设备 ID 不会被删除，后台重启后的目标由配置决定。", fields: [:], destructive: true) }.disabled(model.busy || !model.available("unbind"))
                    }
                }.padding(10)
            }
            ActionResultView(model: model, actions: ["info", "scan", "bind", "unbind"], title: "连接信息与结果")
            Divider()
            HStack {
                Button("重启后台…") { confirmation = .init(action: "restart-service", title: "重启 PhotoPainter 后台？", message: "重新加载配置和设备绑定，保持现有自动推图设置。当前没有在途设备操作时才可执行。", fields: [:]) }.disabled(model.busy || !model.connected || model.snapshot?.transfer.active == true || model.snapshot?.transfer.uncertain == true)
                Button("停止后台…") { confirmation = .init(action: "stop-service", title: "停止 PhotoPainter 后台？", message: "停止采集和设备通信。之后可使用控制台的“启动后台”恢复。", fields: [:]) }.disabled(model.busy || !model.connected || model.snapshot?.transfer.active == true || model.snapshot?.transfer.uncertain == true)
            }
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct ImageTransferView: View {
    @ObservedObject var model: ConsoleModel
    @State private var confirmation: ConfirmOperation?
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button("选择 PNG…") { model.chooseImage() }.disabled(model.busy || !model.available("inspect-image"))
                if let selection = model.selectedImage {
                    Button("发送到相框…") { confirmation = .init(action: "push", title: "显示这张图片？", message: "将发送 \(URL(fileURLWithPath: selection.path).lastPathComponent)，并触发一次实体屏幕刷新。后台会再次核对文件摘要。", fields: ["path": selection.path, "digest": selection.metadata.digest]) }.buttonStyle(.borderedProminent).disabled(model.busy || model.snapshot?.transfer.uncertain == true || !model.available("push"))
                }
            }
            Text("支持 800 × 480、非隔行、完全不透明的六色 PNG，最大 5 MiB。文件先校验，再允许发送。").font(.system(size: 13)).foregroundStyle(.secondary)
            if let selection = model.selectedImage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selection.path).font(.system(size: 12)).textSelection(.enabled)
                    Text("\(selection.metadata.width) × \(selection.metadata.height) · \(bytesText(selection.metadata.bytes))").font(.system(size: 14, weight: .medium))
                    if let image = NSImage(contentsOfFile: selection.path) { Image(nsImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fit).frame(maxHeight: 340) }
                    Text("所选文件预览，尚不代表设备已经显示。").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            if let t = model.snapshot?.transfer {
                Divider(); Text(t.title).font(.system(size: 17, weight: .semibold))
                Text(t.channelLabel).font(.system(size: 13)).foregroundStyle(.secondary)
                if t.total > 0 { ProgressView(value: Double(t.done), total: Double(t.total)); Text("\(t.done) / \(t.total) 字节已发送").monospacedDigit().font(.system(size: 12)) }
                if let timing = t.timingLabel { Text(timing).font(.system(size: 14, weight: .medium)).monospacedDigit() }
                if let message = t.message { Text(message).font(.system(size: 13)) }
                Text("最近设备完成回执：\(clockText(t.completedAt))").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ActionResultView(model: model, actions: ["push"], title: "手动推图结果")
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct ApplicationIOView: View {
    @ObservedObject var model: ConsoleModel
    @State private var appID = "photoframe"
    @State private var characteristic = 0
    @State private var encoding = "UTF-8"
    @State private var input = ""
    @State private var confirmation: ConfirmOperation?
    private var bytes: Data? {
        if encoding == "UTF-8" { return input.data(using: .utf8) }
        if encoding == "Base64" { return Data(base64Encoded: input.filter { !$0.isWhitespace }) }
        let raw = input.filter { !$0.isWhitespace }
        guard raw.count % 2 == 0 else { return nil }
        var out = Data(); var cursor = raw.startIndex
        while cursor < raw.endIndex { let end = raw.index(cursor, offsetBy: 2); guard let value = UInt8(raw[cursor..<end], radix: 16) else { return nil }; out.append(value); cursor = end }
        return out
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                TextField("应用 ID", text: $appID).textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                Stepper("特征索引 \(characteristic)", value: $characteristic, in: 0...3).frame(width: 180)
                Button("读取特征") { model.command("app-read", app: appID, fields: ["characteristic": characteristic]) }.disabled(model.busy || appID.isEmpty || !model.available("app-read"))
            }
            CapabilityReason(model: model, action: "app-read")
            Picker("写入编码", selection: $encoding) { Text("UTF-8").tag("UTF-8"); Text("Hex").tag("Hex"); Text("Base64").tag("Base64") }.pickerStyle(.segmented).frame(maxWidth: 400)
            TextEditor(text: $input).font(.system(size: 13, design: .monospaced)).frame(height: 140).border(Color.secondary.opacity(0.2))
            HStack {
                Text(bytes.map { "\($0.count) / 128 字节" } ?? "编码无效").font(.system(size: 12)).foregroundStyle(bytes == nil || (bytes?.count ?? 0) > 128 ? .orange : .secondary)
                Spacer()
                Button("写入特征…") {
                    guard let bytes else { return }
                    confirmation = .init(action: "app-write", title: "写入应用特征？", message: "应用会解释这些数据，可能触发显示或改变业务状态。命令失败时不会自动重放。", fields: ["app": appID, "characteristic": characteristic, "data_base64": bytes.base64EncodedString()])
                }.disabled(model.busy || appID.isEmpty || bytes == nil || (bytes?.count ?? 0) > 128 || !model.available("app-write"))
            }
            ActionResultView(model: model, actions: ["app-read", "app-write"], title: "应用通信结果")
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct PackageToolsView: View {
    @ObservedObject var model: ConsoleModel
    @State private var elfPath = ""
    @State private var appID = "photoframe"
    @State private var version = "20"
    @State private var confirmation: ConfirmOperation?
    var body: some View {
        DisclosureGroup("从应用 ELF 创建安装包") {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Button("选择 .app.elf…") { FileChooser.open("选择应用 ELF") { elfPath = $0 } }; Text(elfPath.isEmpty ? "尚未选择" : elfPath).font(.system(size: 12)).textSelection(.enabled) }
                HStack { TextField("应用 ID", text: $appID).textFieldStyle(.roundedBorder); TextField("发布版本", text: $version).textFieldStyle(.roundedBorder).frame(width: 150) }
                Button("打包并保存…") {
                    guard let number = UInt32(version) else { return }
                    FileChooser.save("保存应用包", name: "\(appID)-v\(number).pkg") { output in
                        confirmation = .init(action: "package", title: "创建应用包？", message: "校验所选 ELF、应用 ID、ABI 和导入符号，并创建新的安装包；此操作不会安装到设备。", fields: ["path": elfPath, "output": output, "app": appID, "version": number])
                    }
                }.disabled(model.busy || elfPath.isEmpty || appID.isEmpty || UInt32(version) == nil || !model.available("package"))
                ActionResultView(model: model, actions: ["package"], title: "打包结果")
            }.padding(.top, 14)
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct WiFiDraft: Identifiable { let id = UUID(); let ssid: String; let password: String }
struct WiFiConfigurationView: View {
    @ObservedObject var model: ConsoleModel
    @State private var url = ""
    @State private var ssid = ""
    @State private var password = ""
    @State private var index = 1
    @State private var destination = 1
    @State private var drafts: [WiFiDraft] = []
    @State private var confirmation: ConfirmOperation?
    private var base: [String: Any] { url.isEmpty ? [:] : ["url": url] }
    private func parameters(_ values: [String: Any]) -> [String: Any] { base.merging(values) { _, new in new } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("留空自动使用鉴权设备地址；填写时须匹配设备 IP", text: $url).textFieldStyle(.roundedBorder)
            HStack {
                Button("读取 Wi-Fi 列表") { model.command("wifi-list", fields: base) }.disabled(model.busy || !model.available("wifi-list"))
                Button("保存配置备份…") { FileChooser.save("保存 Wi-Fi 配置备份", name: "photopainter-wifi.json") { path in confirmation = .init(action: "wifi-backup", title: "保存 Wi-Fi 配置备份？", message: "备份可能包含 Wi-Fi 凭据，将保存为仅当前用户可读的新文件。", fields: parameters(["path": path])) } }.disabled(model.busy || !model.available("wifi-backup"))
                Button("从配置文件更新…") { FileChooser.open("选择 Wi-Fi 配置 JSON", types: [.json]) { path in confirmation = .init(action: "wifi-update", title: "更新设备 Wi-Fi 配置？", message: "后台读取所选私有配置并更新设备，可能改变设备联网路径。", fields: parameters(["path": path]), destructive: true) } }.disabled(model.busy || !model.available("wifi-update"))
            }
            CapabilityReason(model: model, action: "wifi-list")
            GroupBox("添加网络") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("SSID", text: $ssid).textFieldStyle(.roundedBorder)
                    SecureField("密码，开放网络可留空", text: $password).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("添加到设备…") { confirmation = .init(action: "wifi-add", title: "添加 Wi-Fi 网络？", message: "将网络 \(ssid) 添加到设备配置。密码只通过本机受保护连接交给后台。", fields: parameters(["ssid": ssid, "password": password])); password = "" }.disabled(model.busy || ssid.isEmpty || !model.available("wifi-add"))
                        Button("加入整表草稿") { drafts.append(.init(ssid: ssid, password: password)); ssid = ""; password = "" }.disabled(ssid.isEmpty)
                    }
                }.padding(10)
            }
            if !drafts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("准备写入的完整列表").font(.system(size: 15, weight: .semibold))
                    ForEach(Array(drafts.enumerated()), id: \.element.id) { i, profile in HStack { Text("\(i + 1). \(profile.ssid)"); Spacer(); Text(profile.password.isEmpty ? "开放网络" : "已填写密码").foregroundStyle(.secondary); Button("移除") { drafts.removeAll { $0.id == profile.id } } } }
                    Button("替换设备全部网络…", role: .destructive) {
                        let profiles = drafts.map { ["ssid": $0.ssid, "password": $0.password] }
                        confirmation = .init(action: "wifi-set", title: "替换全部 Wi-Fi 配置？", message: "设备现有列表将被这 \(profiles.count) 项替换，顺序即连接优先级。", fields: parameters(["profiles": profiles]), destructive: true); drafts = []
                    }.disabled(model.busy || !model.available("wifi-set"))
                }
            }
            GroupBox("调整现有列表") {
                HStack {
                    Stepper("序号 \(index)", value: $index, in: 1...32)
                    Stepper("移动到 \(destination)", value: $destination, in: 1...32)
                    Button("移动…") { confirmation = .init(action: "wifi-move", title: "调整连接优先级？", message: "将第 \(index) 项移动到第 \(destination) 位。", fields: parameters(["index": index, "to": destination])) }.disabled(model.busy || !model.available("wifi-move"))
                    Button("删除此网络…", role: .destructive) { confirmation = .init(action: "wifi-remove", title: "删除 Wi-Fi 网络？", message: "删除设备列表第 \(index) 项，可能影响下一次联网。", fields: parameters(["index": index]), destructive: true) }.disabled(model.busy || !model.available("wifi-remove"))
                }.padding(10)
            }
            ActionResultView(model: model, actions: ["wifi-list", "wifi-add", "wifi-set", "wifi-move", "wifi-remove", "wifi-backup", "wifi-update"], title: "Wi-Fi 操作结果")
            Divider()
            LocalWiFiConfigurationView(model: model)
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct USBMaintenanceView: View {
    @ObservedObject var model: ConsoleModel
    @State private var port = ""
    @State private var path = ""
    @State private var restoring = false
    @State private var confirmation: ConfirmOperation?
    private var ports: [JSONValue] { model.results["usb-ports"]?["ports"]?.array ?? [] }
    private var inspection: JSONValue? { guard let r = model.results["usb-inspect"], r["path"]?.text == path else { return nil }; return r }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            notice("USB 维护会让设备进入下载模式并重新启动。请先暂停自动推图；后台会等待当前操作结束并核对绑定设备。", symbol: "cable.connector", color: accent)
            HStack { Button("识别 USB 端口") { model.command("usb-ports") }.disabled(model.busy || !model.available("usb-ports")); TextField("设备端口", text: $port).textFieldStyle(.roundedBorder) }
            ForEach(ports.indices, id: \.self) { i in
                let item = ports[i]
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text(item["port"]?.text ?? "未知端口").monospaced(); Text("\(item["description"]?.text ?? "") · \(item["device_id"]?.text ?? "身份待确认")").font(.system(size: 12)).foregroundStyle(.secondary) }
                    Spacer(); Button("选择") { port = item["port"]?.text ?? "" }
                }.padding(.vertical, 6)
            }
            Button("读取串口启动诊断…") { confirmation = .init(action: "serial-diagnose", title: "读取串口启动诊断？", message: "打开原生 USB 串口可能让设备复位，并中断正在进行的业务。后台会暂停推图并保存过滤后的诊断摘要。", fields: ["port": port]) }.disabled(model.busy || port.isEmpty || model.snapshot?.transfer.active == true || !model.available("serial-diagnose"))
            Button("完整备份 16 MiB Flash…") { confirmation = .init(action: "usb-backup", title: "备份当前设备？", message: "将完整读取已绑定设备的 Flash 并校验，保存到后台私有备份目录。设备会重新启动。", fields: ["port": port]) }.disabled(model.busy || port.isEmpty || model.snapshot?.transfer.active == true || !model.available("usb-backup"))
            Divider()
            Picker("维护类型", selection: $restoring) { Text("更新宿主固件").tag(false); Text("恢复完整备份").tag(true) }.pickerStyle(.segmented).frame(maxWidth: 450).onChange(of: restoring) { _, _ in path = "" }
            HStack {
                Button(restoring ? "选择备份 manifest.json 或 flash.bin…" : "选择宿主 .bin…") { FileChooser.open(restoring ? "选择设备备份" : "选择宿主固件") { chosen in path = chosen; model.command("usb-inspect", fields: ["path": chosen]) } }.disabled(model.busy || !model.available("usb-inspect"))
            }
            if !path.isEmpty { Text(path).font(.system(size: 12)).textSelection(.enabled) }
            if let inspection {
                RawJSONView(title: "文件校验信息", value: inspection)
                Button(restoring ? "恢复备份…" : "备份并更新宿主…", role: restoring ? .destructive : nil) {
                    confirmation = .init(action: restoring ? "usb-restore" : "usb-flash", title: restoring ? "恢复完整 Flash？" : "更新宿主固件？", message: restoring ? "设备将恢复到所选备份的状态，包括应用、目录和配置。后台会先保存当前完整备份，并核对备份设备身份。" : "后台先完整备份并校验，再只写入 factory 宿主分区，最后校验应用槽和配置区域未变。", fields: ["port": port, "path": path, "digest": inspection["digest"]?.text ?? ""], destructive: restoring)
                }.disabled(model.busy || port.isEmpty || model.snapshot?.transfer.active == true || !model.available(restoring ? "usb-restore" : "usb-flash"))
            }
            CapabilityReason(model: model, action: "usb-flash")
            ActionResultView(model: model, actions: ["usb-backup", "usb-flash", "usb-restore", "serial-diagnose"], title: "维护进度与结果")
            Divider()
            ProvisioningView(model: model, port: $port)
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct LocalWiFiConfigurationView: View {
    @ObservedObject var model: ConsoleModel
    @State private var path = ""
    @State private var ssid = ""
    @State private var password = ""
    @State private var index = 1
    @State private var destination = 1
    @State private var confirmation: ConfirmOperation?
    var body: some View {
        DisclosureGroup("编辑本地或 SD 卡 Wi-Fi JSON") {
            VStack(alignment: .leading, spacing: 14) {
                Text("用于已挂载的 SD config/wifi.json 或私有本地副本。取卡前关闭设备；修改通过原有工具的 .tmp/.bak 规则保存，不格式化 SD 卡。").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack {
                    Button("选择配置文件…") { FileChooser.open("选择 Wi-Fi 配置 JSON", types: [.json]) { path = $0; model.command("wifi-file-status", fields: ["path": path]) } }.disabled(model.busy || !model.available("wifi-file-status"))
                    Button("重新读取") { model.command("wifi-file-status", fields: ["path": path]) }.disabled(model.busy || path.isEmpty || !model.available("wifi-file-status"))
                }
                if !path.isEmpty { Text(path).font(.system(size: 12)).textSelection(.enabled) }
                HStack { TextField("SSID", text: $ssid).textFieldStyle(.roundedBorder); SecureField("密码，开放网络可留空", text: $password).textFieldStyle(.roundedBorder) }
                Stepper("网络序号 \(index)", value: $index, in: 1...32)
                HStack {
                    Button("新增或更新此网络…") { confirmation = .init(action: "wifi-file-upsert", title: "修改本地 Wi-Fi 配置？", message: "向所选文件写入网络 \(ssid)，目标位置为第 \(index) 项。密码不在界面结果中回显。", fields: ["path": path, "ssid": ssid, "password": password, "index": index]); password = "" }.disabled(model.busy || path.isEmpty || ssid.isEmpty || !model.available("wifi-file-upsert"))
                    Button("删除此网络…", role: .destructive) { confirmation = .init(action: "wifi-file-remove", title: "删除本地配置中的网络？", message: "移除所选文件中的第 \(index) 项。", fields: ["path": path, "index": index], destructive: true) }.disabled(model.busy || path.isEmpty || !model.available("wifi-file-remove"))
                }
                HStack {
                    Stepper("移动到第 \(destination) 位", value: $destination, in: 1...32)
                    Button("调整顺序…") { confirmation = .init(action: "wifi-file-move", title: "修改本地网络顺序？", message: "将第 \(index) 项移动到第 \(destination) 位。", fields: ["path": path, "index": index, "to": destination]) }.disabled(model.busy || path.isEmpty || !model.available("wifi-file-move"))
                }
                ActionResultView(model: model, actions: ["wifi-file-status", "wifi-file-upsert", "wifi-file-remove", "wifi-file-move"], title: "本地配置结果")
            }.padding(.top, 14)
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}

struct ProvisioningView: View {
    @ObservedObject var model: ConsoleModel
    @Binding var port: String
    @State private var configPath = ""
    @State private var wifiPath = ""
    @State private var credentialsConfirmed = false
    @State private var confirmation: ConfirmOperation?
    private var generated: JSONValue? { model.results["provision-generate"] }
    var body: some View {
        DisclosureGroup("首次配置或重新配置设备凭据") {
            VStack(alignment: .leading, spacing: 16) {
                Text("生成步骤只创建 NVS 文件。写入步骤会改变 Wi-Fi 和设备推图令牌，原后台凭据可能随之失效；后续连接需要与新配置匹配。").font(.system(size: 13)).foregroundStyle(.secondary)
                HStack { Button("选择私有配置文件…") { FileChooser.open("选择 secrets.env 或私有配置", hidden: true) { configPath = $0; credentialsConfirmed = false } }; Text(configPath.isEmpty ? "尚未选择配置" : configPath).font(.system(size: 12)).textSelection(.enabled) }
                HStack { Button("选择可选 Wi-Fi JSON…") { FileChooser.open("选择 Wi-Fi 配置", types: [.json]) { wifiPath = $0 } }; if !wifiPath.isEmpty { Text(URL(fileURLWithPath: wifiPath).lastPathComponent).font(.system(size: 12)); Button("不使用") { wifiPath = "" } } }
                Button("生成 NVS 文件…") {
                    FileChooser.save("保存新的 NVS 文件", name: "photopainter-nvs.bin") { output in
                        var fields: [String: Any] = ["path": configPath, "output": output]
                        if !wifiPath.isEmpty { fields["wifi_path"] = wifiPath }
                        confirmation = .init(action: "provision-generate", title: "生成设备配置镜像？", message: "后台将私有配置转换为含凭据的 NVS 文件，并以受保护权限保存。此步不写设备，也不显示凭据内容。", fields: fields)
                    }
                }.disabled(model.busy || configPath.isEmpty || !model.available("provision-generate"))
                if let generated, generated["type"]?.text == "nvs", let path = generated["path"]?.text, let digest = generated["digest"]?.text {
                    Text("已生成：\(path)").font(.system(size: 12)).textSelection(.enabled)
                    Toggle("我已确认新 Wi-Fi／设备令牌，知道旧连接凭据可能失效", isOn: $credentialsConfirmed).toggleStyle(.checkbox).font(.system(size: 12))
                    Button("备份后写入 NVS…", role: .destructive) { confirmation = .init(action: "usb-provision", title: "重新配置设备凭据？", message: "后台先完整备份设备，再仅写入 NVS 配置分区并校验。此操作会重启设备，可能改变 Wi-Fi 和推图令牌，旧后台可能无法继续鉴权。", fields: ["port": port, "path": path, "digest": digest, "credentials_confirmed": true], destructive: true) }.disabled(model.busy || port.isEmpty || !credentialsConfirmed || model.snapshot?.transfer.active == true || !model.available("usb-provision"))
                }
                CapabilityReason(model: model, action: "provision-generate")
                ActionResultView(model: model, actions: ["provision-generate", "usb-provision"], title: "配置生成与写入结果")
            }.padding(.top, 14)
        }.modifier(ConfirmOperationModifier(model: model, request: $confirmation))
    }
}
