# PhotoPainter Console

独立的 macOS SwiftUI 设备控制台，版本 **0.4.0**。原源码位于 `ai-quota-frame/apps/console`，现拆分到本仓库；Go 后台、采集和 BLE 通信仍由 [ai-quota-frame](https://github.com/M1nt-Ch0c0/ai-quota-frame) 提供。

控制台直接通过受文件权限保护的 Unix socket 连接后台，所有蓝牙与维护操作进入后台唯一队列。界面不创建第二个 BLE 客户端，也不读取私有环境配置或普通服务日志。

## 操作界面

| 页面 | 可视化能力 | 后台操作 |
|---|---|---|
| 运行总览 | 自动采集/推图开关、当前通道、发送进度、耗时与速率、最终完成回执、已确认画面 | snapshot / refresh / pause / resume |
| 设备与应用 | 当前 ABI/版本/阶段/复位码、内存、完整设备字段、A/B 目录、包检查、安装、激活、切换、回退、删除、结束试运行、同版本备用槽重建、ELF 打包 | status / inspect / install / activate / switch / rollback / remove / use-slot / cancel-trial / package |
| 连接与发现 | 广播扫描、鉴权设备信息、保存与解除设备绑定，以及固定后台服务的启动/停止/重启 | scan / info / bind / unbind / LaunchAgent |
| 图片推送 | 严格 PNG 预检、文件摘要确认、手动实体显示、实际 GATT/CoC 通道及结果 | inspect-image / push |
| 应用通信 | 0–3 号应用特征读写、UTF-8/Hex/Base64 输入、字节数限制、文本及十六进制返回值 | app-read / app-write |
| Wi-Fi 配置 | 设备列表、添加、删除、优先级移动、完整列表替换、私有备份、文件更新，以及本地/SD JSON 编辑 | wifi-list / wifi-add / wifi-remove / wifi-move / wifi-set / wifi-backup / wifi-update / wifi-file-status / wifi-file-upsert / wifi-file-remove / wifi-file-move |
| USB 维护 | 端口与设备身份、完整 Flash 备份、宿主 factory 更新、完整备份恢复、文件检查、串口启动诊断、NVS 生成与首次配置 | usb-ports / usb-inspect / usb-backup / usb-flash / usb-restore / serial-diagnose / provision-generate / usb-provision |
| 诊断 | 本机环境检查、真机诊断、能力清单及不可用原因、安全原始状态和操作结果、诊断导出 | doctor / diagnose |

“工作原理”、架构教程和开发示例页面已移除。SDK 与开发说明统一维护在 [项目 Wiki 原件](https://github.com/M1nt-Ch0c0/esp32s3/tree/main/wiki)。

能力清单由后台返回；设备 Wi-Fi 操作需要 HTTP 可达，手填地址也必须匹配刚完成 BLE 鉴权读取的私网 IP。USB 操作需要工具链和已绑定设备。界面不以扫描结果或屏幕残留画面推断设备在线，不用固定值冒充电池、电压等尚未采集的信息。NVS 生成不写设备；实际凭据配置需要确认新凭据影响，再确认备份后写入。开发测试/构建脚本不作为任意 shell 命令执行入口。

## 构建

要求 Apple Silicon Mac、macOS 14 或更新版本，以及 Xcode Command Line Tools：

```sh
sh build.sh
open "dist/PhotoPainter Console.app"
```

产物仅为控制台 `dist/PhotoPainter Console.app`，不在本仓库构建或打包 Go 后台。保持应用标识 `com.m1ntch0c0.photopainter-console`，与原控制台兼容。版本为 0.4.0 / build 5。

后台应安装在 `~/Library/Application Support/ai-quota-frame/ai-quota-frame`，LaunchAgent 标识为 `com.m1ntch0c0.ai-quota-frame`，socket 为运行目录下的 `console/bridge.sock`。请使用支持本次能力接口的配套后台。现有配置、设备凭据和后台启动器不迁入本仓库。

## 接口约定

请求为一行 JSON，`action` 指定操作。设备工作通常先返回排队状态，之后通过 snapshot 读取结果：

- `operation_result_action` / `operation_result`：最近操作结果，界面按操作缓存本次会话中已有结果。
- `device_raw`：鉴权读取的完整安全设备状态。
- `capabilities`：`id/title/category/available/reason`，用于表达真实能力与限制。
- `inspect` 返回 `package`；`inspect-image` 返回 `image`。推图和安装确认携带文件摘要，后台执行前再次核对。
- 写入、删除、恢复等操作携带 `confirmed:true`，GUI 会先显示具体影响。未知完成结果不会自动重放命令。

Wi-Fi 密码使用 SecureField，直接传入 Unix socket，不通过 shell 或进程参数传递，不加入诊断摘要。Flash 备份只由后台读取和保存，GUI 展示元数据及目录，不打开备份内容。

首次配置使用已有私有配置文件路径，由后台生成受保护的 NVS 镜像；界面不读取该文件内容。写入前明确告知 Wi-Fi／设备令牌可能改变、旧鉴权可能失效，并要求独立确认。

## 当前交付边界

本轮按用户要求采用敏捷开发，只做源码编译及实际界面/设备操作检查，不新增自动测试。编译成功不等于每个破坏性维护入口都已经在实机执行。具体部署与设备结果由项目 Wiki 的状态页记录。
