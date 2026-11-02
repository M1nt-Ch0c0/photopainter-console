# PhotoPainter Console 代理指南

本仓库是 macOS SwiftUI 控制台，只负责设备操作界面。Go 后台、蓝牙与 USB 通信由兄弟仓库 `ai-quota-frame` 负责，控制台通过后台的 Unix socket（`~/Library/Application Support/ai-quota-frame/console/bridge.sock`）发送请求。界面和产品规则见 [PRODUCT.md](PRODUCT.md)，构建与请求格式见 [README.md](README.md)。

## 约束

- 保持应用标识 `com.m1ntch0c0.photopainter-console`、后台安装目录 `~/Library/Application Support/ai-quota-frame/` 和 LaunchAgent 标识 `com.m1ntch0c0.ai-quota-frame` 不变。
- 所有设备操作都发给后台，由后台的唯一队列执行。控制台不自建蓝牙或串口连接。
- 新增界面操作前，先确认后台已经提供对应的 `action` 和能力清单项；按能力清单启用按钮。
- 修改设备的操作在界面上明确确认后才发送，并带 `confirmed: true`。回复丢失时读取状态核对，不自动重发。
- 不读取或显示 `.env`、令牌、服务日志、Flash 或 NVS 备份内容。Wi-Fi 密码只通过 socket 传给后台。
- 只显示后台和设备的真实数据，不用固定值填补未采集的信息。
- 改动设备操作时，不在没有用户明确授权的情况下运行控制台去操作真实设备。

## 构建

```sh
sh build.sh
```

需要 Apple Silicon、macOS 14 和 Xcode Command Line Tools。产物在 `dist/`，不提交。新增 Swift 源文件时同步加进 `build.sh` 的编译列表。版本号在 `build.sh` 的 `Info.plist` 里修改。

## 提交

源码、`build.sh` 和文档可以提交。凭据、设备备份、`.pkg`、NVS 镜像和构建产物不入库（见 `.gitignore`）。
