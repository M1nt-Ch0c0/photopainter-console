# 配对界面适配：尚未实机验证

0.4.1 / build 6 离线候选适配新版 ai-quota-frame 后台：新增 pair-status、pair 和 forget 操作，用实际后台进度显示六位码，仅 state=4 时提示按功能键确认。旧“使用已有令牌保存绑定”的说明已删除。

移除本机关系与设备物理重置分开表达；NVS 整块覆盖提示会清除配对，普通 host 更新仍使用仅写 factory 的路径。旧设备 HTTP Wi-Fi 操作注明仅供历史固件。

`sh build.sh` 编译和 ad-hoc 签名通过。今晚没有运行此应用，没有通过 socket 发起设备命令，也没有安装到用户 Applications 目录。该候选与浏览器流程一样尚未实机验证；早上步骤见共享验收清单。
