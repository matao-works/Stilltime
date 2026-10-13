# Stilltime 1.0.0 · 定时防睡眠

让 Mac 在指定时间内不自动睡眠，下载、计算等长任务继续运行。

## 安装

- 支持 macOS 13+，Apple 芯片与 Intel Mac 使用同一通用安装包。
- 下载 `Stilltime-1.0.0-universal.zip`，解压后把 app 放到“应用程序”。无需 Xcode 或 Swift。
- 如果本次 Release 提供 DMG，也可打开后将 app 拖到 Applications。
- 不要下载 Source code，源码需要自行编译。

## 功能

- 常用时长与自定义计时；侧栏只选择时间，开始按钮启动。
- 可切换保持屏幕点亮或允许屏幕自动熄灭。
- 菜单栏控制和剩余时间。
- 本地使用记录、累计时长和今日时长。
- 到时或手动关闭后恢复系统自动睡眠设置；退出 app 也会释放防睡眠限制。

## 首次打开

当前为 ad hoc 本地签名，尚未经过 Apple Developer ID 签名及公证。macOS 可能拦截首次运行。
仅在确认下载来自本项目并信任软件后，按 [Apple 官方说明](https://support.apple.com/102445) 在“系统设置 → 隐私与安全性”选择“仍要打开”。公司管理策略可能不允许此操作。

`SHA256SUMS.txt` 提供安装包校验值。

## 兼容性说明

两种 CPU 架构已编译，最低部署版本检查为 macOS 13；当前实际界面测试在 Apple 芯片 Mac 完成，Intel 与 macOS 13/14 尚未实机验证。
