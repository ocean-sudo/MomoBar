# 📖 MomoBar (墨墨吧)

> 专为 **「墨墨背单词」** 网页版深度定制的 macOS 菜单栏（MenuBar）极简专注小助手。致敬 MenubarX，为您打造极致、纯净、无感的背词体验。

<p align="center">
  <img src="logo4.png" width="100" height="100" alt="MomoBar Logo">
</p>

---

## ✨ 核心特色

- 🚀 **极致轻盈（Native Swift）**：基于原生 macOS Swift 语言与 AppKit 编写，不含任何 Chromium 浏览器内核（非 Electron / Tauri）。运行时仅调用系统自带 WebKit（Safari 内核），**内存占用低至 ~30MB**，几乎不耗电。
- 🕶️ **清爽专注模式 (Focus Mode)**：打开即自动净化墨墨网页！强制隐藏顶部多余导航栏和底部备案页脚，将背单词的 core iframe 自动撑满整个窗口（$400 \times 650$ 手机视口黄金比例），实现完美的 Native App 沉浸体验。
- 👁️ **一键还原开关**：顶部工具栏特设原生**“眼睛”图标 (👁/🕶)**，点击瞬间在“专注模式”和“标准完整网页”间无缝切换，不影响修改密码、查看订单或退出登录等操作。
- 💾 **自动历史记忆**：自动保存您最后的学习网址（使用 macOS UserDefaults 存储），下次在任务栏点开自动恢复上次的背词进度。
- ⌨️ **完美支持快捷键**：支持标准的 `Command + C`（复制）、`Command + V`（粘贴）、`Command + A`（全选）等常用剪贴板操作。
- ⏻ **一键安全退出**：工具栏最右侧设计了电源按钮 (⏻)，需要关闭时一键即可彻底退出。

---

## 📦 下载与安装

### 方式 1：从 Release 下载安装
1. 进入本项目的 **Releases** 页面，下载最新的 `MomoBar.zip`。
2. 双击解压，将得到的 `MomoBar.app` 拖入您的 **应用程序 (Applications)** 文件夹。
3. **首次运行提示（重要）**：
   由于应用为个人开发者编译，未进行苹果官方付费签名，双击运行时可能会被系统 Gatekeeper 阻止。
   * **解决方法**：请在 `MomoBar.app` 上**右键（或按住 Control + 点击） -> 选择“打开”**，并在弹出的安全警告框中点击**“打开”**确认。只需一次授权，以后即可直接双击秒开！

---

## 🛠 本地开发与编译

如果您想自己在本地修改代码并编译：

1. 克隆本项目：
   ```bash
   git clone <your-repo-url>
   cd MomoBar
   ```

2. 运行本地编译命令：
   ```bash
   swiftc -O main.swift -o MomoBar
   ```

3. 打包成 `.app`（或直接运行二进制文件 `./MomoBar`）：
   ```bash
   mkdir -p MomoBar.app/Contents/MacOS
   mkdir -p MomoBar.app/Contents/Resources
   cp MomoBar MomoBar.app/Contents/MacOS/
   cp Info.plist MomoBar.app/Contents/
   cp AppIcon.icns MomoBar.app/Contents/Resources/
   codesign --force --deep --sign - MomoBar.app
   ```

---

## 🤝 鸣谢
- 感谢 [墨墨背单词](https://www.maimemo.com/) 提供如此优秀、高效的抗遗忘背词服务。
- 感谢 [MenubarX](https://menubarx.app/) 带来的绝妙菜单栏浏览器灵感。
