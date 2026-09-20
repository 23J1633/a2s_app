[中文](#中文) | [English](#english)

# A2S 手机端

## 中文

## A2S 生态（同系列开源仓库）

A2S 按组件拆分为以下同系列仓库，所有者均为 `23J1633`。/ A2S is split into the following sibling repositories, all owned by `23J1633`.

| 仓库 / Repository | 作用 / Role | GitHub |
|---|---|---|
| A2Switch | Windows 桌面控制中心 / Windows desktop control center | [23J1633/A2Switch](https://www.github.com/23J1633/A2Switch) |
| cc2server | Claude Code 桥接器 / Claude Code bridge | [23J1633/cc2server](https://www.github.com/23J1633/cc2server) |
| codex2server | Codex 桥接器 / Codex bridge | [23J1633/codex2server](https://www.github.com/23J1633/codex2server) |
| dsh2server | DeepSeek Harness 插件 / DeepSeek Harness plugin | [23J1633/dsh2server](https://www.github.com/23J1633/dsh2server) |
| server-api | 中转服务与 Web 控制台 / relay server and Web console | [23J1633/server-api](https://www.github.com/23J1633/server-api) |
| a2s_app | Flutter Android 客户端 / Flutter Android client | [23J1633/a2s_app](https://www.github.com/23J1633/a2s_app) |
| scripts | 跨仓库验收脚本 / cross-repository acceptance scripts | [23J1633/scripts](https://www.github.com/23J1633/scripts) |
| ICON | A2S 品牌源图 / A2S brand source artwork | [23J1633/ICON](https://www.github.com/23J1633/ICON) |
| artifacts | 脱敏交付验证产物 / sanitized delivery evidence | [23J1633/artifacts](https://www.github.com/23J1633/artifacts) |

`a2s_app` 是 A2S 的 Flutter Android 控制端，Android application ID 为 `io.a2s.mobile`。它沿用服务器网页端的工作流：先选择设备，再单独选择设备上的智能体，进入聊天；左侧抽屉集中管理历史会话、统计、设置和扫码配对。界面使用 Material 3，支持浅色、深色、系统主题、动态取色、减少动画和真实品牌图标。

## 已实现能力

- 服务器地址和管理员 key 手动登录；管理员 key 只用于登录和查看设备摘要。
- 设备 key 二次解锁；未解锁设备不能读取会话、工作区、文件、任务、终端或下发命令。
- 一次性二维码配对：支持相机扫描和相册图片识别，二维码刷新、过期、重复兑换和撤销均有明确提示。
- 设备与智能体分离选择，内置 Claude、OpenAI Codex、DeepSeek Harness 的真实 SVG 品牌图标。
- 聊天、流式事件、停止/中断、历史搜索、重命名、分叉、归档/恢复、附件、Markdown、工具调用、审批和结构化提问。
- 工作区目录和文本预览、运行轨迹、任务/目标、模型/权限/审批设置、插件配置、统计、日志和高级方法调试。
- 真实远程终端：xterm 显示、命令发送、Ctrl/Esc/Tab、方向键、尺寸同步、保活、回放和断线重连。
- 服务器管理页：管理员 key 只在内存中使用，可查看/重命名/撤销移动设备，登记/吊销设备 key，生成或作废配对二维码并读取服务日志。
- SSE 事件序号去重、断线回拉、请求幂等、手机心跳、草稿按服务器/设备/智能体/会话隔离保存。

## 连接地址

在 App 中填写服务器的完整插件端点，例如：

```text
http://127.0.0.1:50443/a2s-api
```

App 会在该地址后使用 `/mobile/v1` 手机协议；`/dsh-api` 别名同样支持。Pixel 9 Pro 模拟器本地联调使用：

```powershell
adb reverse tcp:50443 tcp:50443
```

然后在 App 中填写 `http://127.0.0.1:50443/a2s-api`。生产环境应使用 HTTPS，系统证书校验保持开启。

## 手动连接与扫码配对

手动连接需要管理员 key；登录后只能看到设备摘要。点击设备并输入 A2Switch 本地设备 key 才能解锁该设备。

服务端网页端的“设置 → 移动设备连接”进入后会按已勾选设备自动生成二维码，也可以手动刷新；改变勾选或端点会轮换并撤销旧码。二维码包含端点、随机票据和一次性授权信息，有效期为 5 分钟，服务器同时只保留一张有效码。App 的“设置 → 扫描二维码”支持相机和相册识别，成功后会保存独立手机凭据并解锁二维码勾选的设备。

## 远程终端

终端默认关闭。需要在对应 A2Switch/桥接器配置中显式打开 `allowRemoteTerminal` 后，App 的“工具 → 终端”才会显示连接能力。Windows 桥接器默认启动 PowerShell，Linux/macOS 使用 `$SHELL` 或 `/bin/bash`。每个桥接器最多 4 个终端，每个终端保存 1 MiB 回放，120 秒无保活会回收。

## 本地开发

```powershell
cd D:\Project\A2S\a2s_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release --split-per-abi
```

安装调试 APK：

```powershell
adb install -r D:\Project\A2S\artifacts\a2s_app-debug.apk
```

本次交付的 APK 为本地测试签名，只用于联调和验收。SHA-256（`artifacts/a2s_app-debug.apk`）：

```text
5DA9050F27FFD6829ADBFB06913405092066C0CBFBD9674CFFF464281C0A54D6
```

## Release 签名

源码不会回退到调试签名。没有 `android/key.properties` 时可以生成未签名的 Release 分包，用于 CI 验证，但不能直接上架。正式发布前：

1. 复制 `android/key.properties.example` 为 `android/key.properties`；
2. 创建并妥善保管 upload keystore；
3. 填写 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`；
4. 执行 `flutter build apk --release --split-per-abi`；
5. 使用 Android SDK 的 `apksigner verify --print-certs <apk>` 复核签名。

`key.properties`、`*.jks`、`*.keystore` 和 `android/local.properties` 均已加入 `.gitignore`。本机已验证三个 ABI 的未签名 Release 分包可完整构建；最终商店签名必须由发布者自己的密钥完成。

Windows 上若 Pub 缓存在 C: 而项目在 D:，Kotlin 增量缓存会因跨盘符路径失效。项目已在 `android/gradle.properties` 中关闭 Kotlin 增量编译，以换取可复现的 Debug/Release 构建。

## 目录说明

- `lib/main.dart`：Material 3 页面、抽屉、设备/智能体选择、扫码、聊天、工作区、轨迹、终端和设置。
- `lib/state/app_state.dart`：Riverpod 状态、手机凭据、SSE 重连、事件回拉、草稿和交互应答。
- `lib/core/api_client.dart`：HTTP 手机协议适配器和请求幂等 ID。
- `assets/a2s-logo.png`、`assets/brands/*.svg`：A2S、Claude、OpenAI、DeepSeek 品牌图标。

服务端手机协议和管理页位于 `server-api/lib/mobile.js`、`server-api/public/js/settings.js`。服务端接口端点、一次性配对和授权模型见仓库根目录的移动端验收报告。

## 许可证

代码采用 MIT License，见 `LICENSE`。Claude、OpenAI、DeepSeek 等名称和品牌图标属于各自权利人，仅用于标识兼容的智能体。

## English

`a2s_app` is the Flutter Android controller for A2S. Its Android application ID is `io.a2s.mobile`. The workflow mirrors the Web console: choose a device, choose an Agent on that device, then enter chat. The navigation drawer provides history, statistics, settings, and QR pairing. The Material 3 UI supports light/dark/system themes, dynamic color, reduced motion, and authentic Agent marks.

### Features

- Manual server/admin-key sign-in, followed by a separate device-key unlock step.
- Single-use QR pairing from camera or gallery, with clear refresh, expiry, replay, and revocation states.
- Separate device and Agent selection for Claude, Codex, and DeepSeek Harness.
- Chat, streaming, stop/interrupt, search, rename, fork, archive/restore, attachments, Markdown, tools, approvals, and structured questions.
- Workspaces and text previews, trajectory, tasks/goals, models, permissions, plugin settings, statistics, logs, and advanced method debugging.
- Real remote terminals with xterm rendering, control keys, resize, keepalive, replay, and reconnect.
- Server administration for mobile clients, device keys, pairing tickets, and logs.
- SSE sequence deduplication, backlog recovery, idempotent requests, heartbeat, and drafts isolated by server/device/Agent/session.

### Connection and pairing

Enter the complete plugin endpoint, for example `https://example.com/a2s-api`. The app derives `/mobile/v1`; the legacy `/dsh-api` alias is also accepted. Production deployments must use HTTPS with normal certificate validation. For an Android emulator connected to the local service, run `adb reverse tcp:50443 tcp:50443` and use `http://127.0.0.1:50443/a2s-api`.

Manual connection uses the administrator key only to authenticate and list device summaries. A device remains locked until its A2Switch device key is supplied. The Web console can instead issue a five-minute, single-use QR ticket for selected devices; redeeming it creates a separate mobile credential.

### Remote terminal

Terminal access is disabled by default and appears only after `allowRemoteTerminal` is explicitly enabled for the bridge. Windows uses PowerShell; Linux/macOS use `$SHELL` or `/bin/bash`. Each bridge allows up to four terminals, keeps 1 MiB of replay, and reclaims a terminal after 120 seconds without keepalive.

### Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release --split-per-abi
```

Release signing never falls back to debug signing. Copy `android/key.properties.example`, provide the publisher's upload keystore values, build the split APKs, and verify them with `apksigner`. Keystores and local signing configuration are ignored by Git.

### Project layout and license

`lib/main.dart` contains the Material UI; `lib/state/app_state.dart` owns Riverpod state, credentials, SSE recovery, drafts, and responses; `lib/core/api_client.dart` implements the mobile HTTP protocol. Branding is under `assets/`. The code uses the MIT License; third-party names and marks remain the property of their owners.

