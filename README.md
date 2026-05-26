# 📖 MomoBar (墨墨吧)

专为 **「墨墨背单词」** 网页版深度定制的 macOS 菜单栏 (MenuBar) 极简专注小助手。致敬 MenubarX，为您打造极致、纯净、无感的背词体验。

<p align="center">
  <img src="logo4.png" width="128" alt="MomoBar Logo">
</p>

---

## 📸 实机运行效果

<p align="center">
  <img src="screenshot.png" width="400" alt="MomoBar 实机运行截图">
</p>

---

## ✨ 核心特色

- 🚀 **极致轻盈 (Native Swift)**：基于原生 macOS Swift 语言与 AppKit 编写，不含任何 Chromium 内核。运行时仅调用系统自带 WebKit（Safari 内核），**内存占用低至 ~30MB**，极度省电省内存。
- 🕶️ **清爽专注模式 (Focus Mode)**：打开即自动净化墨墨网页版顶部导航栏和底部备案页脚，核心背词窗口自动撑满 $400 \times 650$ 的手机黄金比例视口。
- 🤖 **协议自动跳过 (Auto Agree)**：智能穿透 Shadow DOM，自动检测公测警告并在一瞬间自动勾选、自动点击“开始学习”按钮，秒级免干预进入学习。
- 👁️ **一键还原开关**：顶部工具栏特设“眼睛”图标，点击瞬间在“专注模式”与“原网页状态”之间无缝切换，不影响修改密码、登出或支付。
- 💾 **自动历史记忆**：使用 `UserDefaults` 自动本地存储上次背词网址，每次打开自动续播。
- ⌨️ **完美支持快捷键**：支持标准的 `Cmd+C`（复制）、`Cmd+V`（粘贴）、`Cmd+A`（全选）等系统剪贴板操作。
- ⚙️ **齿轮设置菜单**：集成配置下拉菜单，提供全局热键快捷修改面板，支持热键一键保存与持久化。

---

## ⌨️ 快捷键说明

| 功能 | 默认快捷键 | 说明 |
| :--- | :--- | :--- |
| **显示/隐藏 MomoBar** | `Command + Shift + M` | 全局生效，无需开启任何系统“辅助功能”授权 |
| **清爽/还原模式切换** | 顶部眼睛按钮 | 无缝切换，不影响修改密码、登出或支付 |

---

## 📦 安装与使用

### 方式 1：使用 DMG 安装（推荐 🌟）
1. 从 **Releases** 页面下载最新的 `MomoBar.dmg`。
2. 双击打开，将 **MomoBar** 拖入右侧的 **Applications** 快捷方式中即可完成安装。
3. **首次运行提示（重要）**：
   * 请在“应用程序”文件夹的 `MomoBar` 上**右键（或 Control + 点击） -> 选择“打开”**。
   * 在弹出的安全窗口中点击 **“打开”** 即可！只需一次性信任，以后双击直接秒开。

### 方式 2：使用 ZIP 安装
1. 下载最新的 `MomoBar.zip` 并解压。
2. 将解压出来的 `MomoBar.app` 拖入您的 **应用程序 (Applications)** 文件夹。
3. 首次运行同样需要 **右键选择打开**。

---

## 🛠 本地开发与编译

如果您想自己在本地修改代码并编译：

```bash
# 1. 克隆项目
git clone <your-repo-url>
cd MomoBar

# 2. 编译项目（解耦版多文件编译）
swiftc -O main.swift AppDelegate.swift WebViewController.swift HotkeySettingsView.swift HotkeyManager.swift -o MomoBar

# 3. 打包为 MomoBar.app Bundle
mkdir -p MomoBar.app/Contents/MacOS
mkdir -p MomoBar.app/Contents/Resources
cp MomoBar MomoBar.app/Contents/MacOS/
cp Info.plist MomoBar.app/Contents/
cp AppIcon.icns MomoBar.app/Contents/Resources/
codesign --force --deep --sign - MomoBar.app
```

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。
