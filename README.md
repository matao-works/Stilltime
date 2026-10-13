# Stilltime · 定时防睡眠

让 Mac 在指定时间内不自动睡眠，下载、计算等长任务继续运行。计时结束后恢复系统自动睡眠设置。

## 下载与安装

**要求：macOS 13 或更高版本。Apple 芯片和 Intel Mac 使用同一安装包，无需安装开发工具。**

1. 在 [Releases](https://github.com/matao-works/Stilltime/releases/latest) 下载 `Stilltime-1.0.0-universal.zip`。
2. 解压 ZIP，把 **Stilltime.app** 拖到 **应用程序**。
3. 从“应用程序”打开 Stilltime，选择时长，点击 **开始防睡眠**。

若 Release 提供 `.dmg`，也可打开后将 app 拖到 Applications。请下载 Release 附件，不要下载 `Source code`；后者是源码。

### 首次打开提示

当前版本采用本地 ad hoc 签名，**尚未进行 Apple Developer ID 签名和公证**。浏览器下载的 app 可能被 macOS 拦截。

仅在确认下载来自本仓库并信任该软件后，按 [Apple 官方说明](https://support.apple.com/102445)，在“系统设置 → 隐私与安全性”中选择“仍要打开”。公司管理策略可能不允许此操作，需要联系 IT。项目不要求关闭 Gatekeeper 或 SIP。

## 使用

- **快捷选择**：只选择时间；点击 **开始防睡眠** 才开始。
- **常用时长 / 自定义**：设置防睡眠持续多久。最短 1 分钟，最长自定义 23 小时 59 分钟。
- **保持屏幕点亮**：开启防睡眠时，同时保持屏幕亮着。
- **允许屏幕自动熄灭**：屏幕可以熄灭，电脑继续运行。计时中也能切换。
- **关闭防睡眠**：立即恢复系统自动睡眠设置；到时也会自动结束，不会强制电脑立即睡眠。
- **菜单栏**：快速开始、查看剩余时间、重新打开窗口或退出。
- **使用记录**：查看实际使用时长、累计时长、今日时长和历史记录。最近 1,000 条详情保存在本机，累计总数继续保留。

防睡眠针对电脑的自动闲置睡眠。合盖、手动睡眠、关机和公司管理策略仍可能中断任务。

## 更新和卸载

更新前先从菜单栏退出 Stilltime，再用新版替换“应用程序”中的旧版。历史记录保存在本机，不随 app 替换而清除。

卸载时先退出，再将 `Stilltime.app` 移到废纸篓。

## 本地编译

需要 Swift 6 和 macOS SDK（Xcode 或兼容的 Command Line Tools）。

```sh
./build.sh                 # 默认生成 arm64 + x86_64 通用 app
./build.sh --native        # 仅编译当前机器架构，用于开发
open Stilltime.app
./scripts/package.sh      # 生成 dist/ 下的 DMG、ZIP 和 SHA256 校验文件
```

代码使用系统 `/usr/bin/caffeinate` 管理防睡眠，无需管理员权限，不上传使用记录。构建脚本默认使用本地签名，正式免拦截分发需要开发者提供 Developer ID 证书并进行公证。

## License

MIT
