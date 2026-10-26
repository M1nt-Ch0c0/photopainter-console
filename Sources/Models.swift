import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum JSONValue: Codable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let v): try c.encode(v); case .array(let v): try c.encode(v); case .string(let v): try c.encode(v); case .number(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .null: try c.encodeNil() }
    }
    subscript(_ key: String) -> JSONValue? { if case .object(let o) = self { return o[key] }; return nil }
    var array: [JSONValue] { if case .array(let a) = self { return a }; return [] }
    var text: String {
        switch self { case .string(let v): return v; case .number(let v): return v.rounded() == v ? String(format: "%.0f", v) : String(v); case .bool(let v): return v ? "是" : "否"; case .null: return "未提供"; default: return pretty }
    }
    var pretty: String { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return (try? e.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
}
struct DeviceCapability: Decodable, Identifiable {
    let id: String; let title: String; let category: String; let available: Bool; let reason: String?
}
struct ImageMetadata: Decodable { let bytes: Int; let digest: String; let width: Int; let height: Int }

struct ConsoleResponse: Decodable {
    let state: ServiceSnapshot?; let error: String?; let packageInfo: PackageMetadata?; let image: ImageMetadata?
    enum CodingKeys: String, CodingKey { case state, error, image, packageInfo = "package" }
}
struct PackageMetadata: Decodable { let app: String; let version: Int; let abi: Int; let bytes: Int; let digest: String }
struct PackageSelection: Identifiable { let path: String; let metadata: PackageMetadata; let target: SlotSelection?; var id: String { metadata.digest } }
struct SlotSelection: Identifiable {
    let app: DeviceApplication; let slot: Int
    var id: String { "\(app.id)-\(slot)" }
    var version: Int? { app.version(at: slot) }
    var label: String { "\(app.displayName) · \(slot == 0 ? "A" : "B") 槽 v\(version ?? 0)" }
    var needsPackage: Bool { slot != app.active && slot != app.pending && slot != app.previous }
}
struct ServiceSnapshot: Decodable {
    let schema: Int
    let startedAt: String
    let observedAt: String
    let automatic: Bool
    let intervalSeconds: Int
    let theme: String
    let transport: String
    let deviceId: String
    let sourceState: String
    let lastFetch: String?
    let nextFetch: String?
    let accountCount: Int
    let warningCount: Int
    let transfer: TransferState
    let device: DeviceState?
    let deviceObservedAt: String?
    let deviceError: String?
    let operation: String?
    let operationError: String?
    let operationDone: Int?
    let operationTotal: Int?
    let previewPath: String?
    let events: [ConsoleEvent]
    let capabilities: [DeviceCapability]?
    let operationResult: JSONValue?
    let operationResultAction: String?
    let deviceRaw: JSONValue?
}
struct TransferState: Decodable {
	let channel: String?
	let uploadDurationMs: Int64?
	let bytesPerSecond: Double?
    let message: String?
    let stage: String
    let done: Int
    let total: Int
    let startedAt: String?
    let completedAt: String?
    let uncertain: Bool
    var active: Bool { ["rendering", "connecting", "uploading", "displaying", "recovering"].contains(stage) }
    var channelLabel: String {
        switch channel {
        case "l2cap-coc": return "L2CAP CoC"
        case "gatt": return "GATT 兼容通道"
        default: return "等待选择数据通道"
        }
    }
    var timingLabel: String? {
        guard let ms = uploadDurationMs, ms > 0, let rate = bytesPerSecond else { return nil }
        return String(format: "发送 %.1f 秒 · 平均 %.1f KiB/s", Double(ms) / 1000, rate / 1024)
    }
    var title: String {
        switch stage {
        case "rendering": return "正在生成图片"
        case "connecting": return "正在连接设备并检查收图应用"
        case "uploading": return "正在通过蓝牙上传"
        case "displaying": return "等待屏幕刷新完成"
        case "recovering": return "正在查询完成回执"
        case "complete": return "屏幕已确认刷新"
        case "unchanged": return "画面未变，无需重复刷新"
        case "unknown": return "这次刷新结果尚不确定"
        case "rejected": return "本轮推图已停止"
        case "failed": return "推图未成功，等待重试"
        default: return "等待下一次数据更新"
        }
    }
}
struct DeviceState: Decodable {
	let phase: String?
	let payloadAbiMinor: Int?
	let cocVersion: Int?
	let cocState: Int?
    let loadedApp: Int
    let loaded: Int?
    let ready: Bool?
    let trialApp: Int?
    let version: Int
    let payloadAbi: Int
    let runtimeReady: Bool
    let confirmed: Bool
    let generation: Int
    let uptimeMs: UInt64
    let resetReason: Int
    let freePsram: Int
    let freeInternalRam: Int
    let cacheBytes: Int
    let bleCharacteristics: Int
    let lastSwitchSource: String
    let apps: [DeviceApplication]
    var currentName: String { apps.first(where: { $0.bank == loadedApp })?.id ?? "未运行应用" }
}
struct DeviceApplication: Decodable, Identifiable {
    let id: String
    let bank: Int
    let active: Int
    let previous: Int
    let pending: Int
    let versions: [Int?]
    let abi: Int
    let buttonEligible: Bool
    func version(at slot: Int) -> Int? { versions.indices.contains(slot) ? versions[slot] : nil }
    var version: Int? { version(at: active) }
    var displayName: String { id == "photoframe" ? "相框" : id == "color-test" ? "六色色条" : id }
}
struct ConsoleEvent: Decodable, Identifiable {
    let at: String
    let kind: String
    let message: String
    var id: String { at + kind + message }
}
func parsedDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}
func clockText(_ value: String?) -> String {
    guard let date = parsedDate(value) else { return "尚无记录" }
    return date.formatted(date: .omitted, time: .standard)
}
func bytesText(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory) }

@MainActor
final class ConsoleModel: ObservableObject {
    @Published var snapshot: ServiceSnapshot?
    @Published var connected = false
    @Published var error = ""
    @Published var submitting = false
    @Published var hasPolled = false
    @Published var preview: NSImage?
    @Published var pendingPackage: PackageSelection?
    @Published var results: [String: JSONValue] = [:]
    @Published var rawSnapshot: JSONValue?
    @Published var selectedImage: (path: String, metadata: ImageMetadata)?
    private var previewStamp = ""
    private var polling = false
    private var connectionError = false
    let binary = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ai-quota-frame/ai-quota-frame")
    var busy: Bool { submitting || !(snapshot?.operation ?? "").isEmpty }
    var deviceFresh: Bool {
        guard connected, let at = parsedDate(snapshot?.deviceObservedAt), (snapshot?.deviceError ?? "").isEmpty else { return false }
        return Date().timeIntervalSince(at) < 120
    }
    func runPolling() async {
        guard !polling else { return }; polling = true
        defer { polling = false }
        while !Task.isCancelled {
            await request("snapshot")
            try? await Task.sleep(for: .seconds(2))
        }
    }
    func command(_ action: String, app: String? = nil, digest: String? = nil, target: SlotSelection? = nil, fields: [String: Any] = [:]) {
        guard !submitting else { return }
        submitting = true
        Task { await request(action, app: app, digest: digest, target: target, fields: fields); submitting = false }
    }
    func request(_ action: String, app: String? = nil, digest: String? = nil, target: SlotSelection? = nil, fields: [String: Any] = [:]) async {
        let socketPath = binary.deletingLastPathComponent().appendingPathComponent("console/bridge.sock").path
        var payload = fields
        payload["action"] = action
        if let app { payload[action == "inspect" || action == "install" || (action == "use-slot" && digest != nil) ? "path" : "app"] = app }
        if let digest { payload["digest"] = digest }
        if let target {
            payload["app"] = target.app.id; payload["slot"] = target.slot
            if let version = target.version { payload["version"] = version }
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let result = await Task.detached(priority: .utility) { () -> (Data?, String?) in
            do {
                return (try ConsoleSocket.call(path: socketPath, payload: requestData), nil)
            } catch { return (nil, "后台未连接或未及时响应。请确认 PhotoPainter Renderer 正在运行。") }
        }.value
        hasPolled = true
        guard let data = result.0 else { connected = false; connectionError = true; error = result.1 ?? "后台未连接"; return }
        do {
            let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(ConsoleResponse.self, from: data)
            rawSnapshot = (try? JSONDecoder().decode(JSONValue.self, from: data))?["state"]
            if let state = response.state {
                snapshot = state; connected = true
                if let action = state.operationResultAction, let value = state.operationResult { results[action] = value }
                if connectionError { error = ""; connectionError = false }
                let stamp = state.transfer.completedAt ?? ""
                if stamp != previewStamp, let path = state.previewPath {
                    // Only the backend's own completion artifact may be shown.
                    let expected = binary.deletingLastPathComponent().appendingPathComponent("console-last-frame.png").path
                    if path == expected { preview = NSImage(contentsOfFile: path); previewStamp = stamp }
                }
            } else { connected = false; connectionError = true }
            if action != "snapshot" || response.error != nil { error = response.error ?? "" }
            if action == "inspect", let metadata = response.packageInfo, let path = app {
                if let target, metadata.app != target.app.id || metadata.version != target.version {
                    error = "请选择 \(target.app.id) v\(target.version ?? 0) 的应用包；所选文件是 \(metadata.app) v\(metadata.version)。"
                } else { pendingPackage = PackageSelection(path: path, metadata: metadata, target: target) }
            }
            if action == "inspect-image", let metadata = response.image, let path = fields["path"] as? String { selectedImage = (path, metadata) }
        } catch { connected = false; connectionError = true; self.error = "后台尚未提供控制台状态。请使用配套版本的 PhotoPainter Renderer。" }
    }
    func available(_ action: String) -> Bool {
        guard connected else { return false }
        guard let capabilities = snapshot?.capabilities else {
            return ["snapshot", "status", "refresh", "pause", "resume", "inspect", "install", "activate", "switch", "rollback", "use-slot", "cancel-trial"].contains(action)
        }
        return capabilities.first(where: { $0.id == action })?.available ?? false
    }
    func capabilityReason(_ action: String) -> String? { snapshot?.capabilities?.first(where: { $0.id == action })?.reason }
    func chooseImage() {
        let panel = NSOpenPanel(); panel.title = "选择要显示的 PNG"; panel.allowedContentTypes = [.png]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self.command("inspect-image", fields: ["path": url.path]) }
        }
    }
    func exportDiagnostics() {
        guard let rawSnapshot else { return }
        let panel = NSSavePanel(); panel.title = "导出诊断摘要"; panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "photopainter-diagnostics.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try Data(rawSnapshot.pretty.utf8).write(to: url, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
            catch { Task { @MainActor in self.error = "诊断摘要保存失败。" } }
        }
    }
    func choosePackage(restoring target: SlotSelection? = nil) {
        let panel = NSOpenPanel()
        panel.title = "选择 PhotoPainter 应用包"
        panel.message = target.map { "选择 \($0.app.id) v\($0.version ?? 0) 的 .pkg 应用包。确认后重新安装到备用槽并激活，保留当前活动版本。" } ?? "选择 .pkg 应用包。安装只写入备用槽，激活是单独操作。"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self.command("inspect", app: url.path, target: target) }
        }
    }
    func startService() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let label = "gui/\(getuid())/com.m1ntch0c0.ai-quota-frame"
        Task {
            let result = await Task.detached { () -> Bool in
                func launch(_ args: [String]) -> Int32 {
                    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = args
                    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
                    do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
                }
                guard launch(["enable",label]) == 0 else { return false }
                if launch(["print",label]) == 0 { return launch(["kickstart",label]) == 0 }
                return launch(["bootstrap","gui/\(getuid())",home.appendingPathComponent("Library/LaunchAgents/com.m1ntch0c0.ai-quota-frame.plist").path]) == 0
            }.value
            if !result { error = "后台启动失败。请检查现有 LaunchAgent 是否已安装。" }
            await request("snapshot")
        }
    }
    func serviceAction(_ action: String) {
        guard !busy, snapshot?.transfer.active != true, snapshot?.transfer.uncertain != true else { error = "请等待设备操作和当前推图结束，再管理后台。"; return }
        let target = "gui/\(getuid())/com.m1ntch0c0.ai-quota-frame"
        submitting = true
        Task {
            let ok = await Task.detached { () -> Bool in
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p.arguments = action == "stop-service" ? ["bootout", target] : ["kickstart", "-k", target]
                p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
                do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false }
            }.value
            submitting = false
            if !ok { error = "后台管理失败，请检查现有 LaunchAgent 状态。" }
            await request("snapshot")
        }
    }
}
