# DevSwitcher2

<div align="center">

![DevSwitcher2 Logo](https://img.shields.io/badge/DevSwitcher2-2.1-blue?style=for-the-badge)
[![macOS](https://img.shields.io/badge/macOS-12.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.9+-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

**高效优雅的 macOS 窗口切换工具**

一个现代化的菜单栏应用，提供增强的窗口和应用切换体验，让您的工作流程更加流畅。

[📥 下载最新版本](https://github.com/vaspike/DevSwitcher2/releases) · [🐛 报告问题](https://github.com/vaspike/DevSwitcher2/issues) · [💡 功能建议](https://github.com/vaspike/DevSwitcher2/discussions)

</div>

## ✨ 主要特性

### 🚀 应用切换器增强
- **应用内窗口切换器**: 同一应用内的窗口快速切换（增强版 Command + `）
- **应用间切换器**: 所有应用间的切换（增强版 Command + Tab）

### 🎯 智能窗口识别
- 智能标题提取，支持多种策略（优先部分、末尾部分、自定义分隔符）
- 自动识别项目名称（如 Xcode 项目、VSCode 工作区等）
- 可配置的应用特定规则

### ⚡️ 极致性能
- 图标缓存系统，流畅的视觉体验
- 多显示器智能支持
- 60Hz 实时响应
- 优化的内存管理

### 🛠 高度可定制
- 完全自定义的快捷键设置
- 灵活的窗口标题显示策略

### 🌐 国际化支持
- 完整的中英文本地化
- 动态语言切换
- 系统语言自动检测

## 📸 预览

![1614X1064/2.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/szAC/1614X1064/2.png)

![1448X1002/1.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/2ifI/1448X1002/1.png)

![2002X1436/4.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/z493/2002X1436/4.png)

![3.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/Mamo/3574X2316/3.png/webp)

</div>

## 🚀 快速开始

### 系统要求
- macOS 13.0 或更高版本
- 辅助功能权限（首次运行时会自动引导设置）

### 安装方式

#### 方法 1: HomeBrew安装

```bash
# Install
brew tap vaspike/devswitcher2 && brew install --cask DevSwitcher2
```
```bash
# Uninstall
brew uninstall devswitcher2
```

#### 方法 2: 下载发布版本
1. 访问 [Releases 页面](https://github.com/vaspike/DevSwitcher2/releases)
2. 下载最新的 `DevSwitcher2.dmg`
3. 打开 dmg 文件，将应用拖拽到应用程序文件夹
4. 启动应用并授予必要权限

#### 方法 3: 从源码构建
```bash
# 克隆仓库
git clone https://github.com/vaspike/DevSwitcher2.git
cd DevSwitcher2

# 使用 Xcode 打开项目
open DevSwitcher2.xcodeproj

# 或者使用命令行构建
xcodebuild -project DevSwitcher2.xcodeproj -scheme DevSwitcher2 -configuration Release
```

### 首次设置
1. **授予辅助功能权限**：应用会自动引导您完成设置
2. **配置快捷键**：默认使用 Command + ` (应用内窗口切换器) 和 Command + Tab (应用间切换器)
3. **自定义设置**：通过菜单栏图标访问偏好设置
4. **注意**: 首次安装时, `应用间切换器`功能是未启用的, 需要在偏好设置中手动开启

## 🎮 使用指南

### 基本操作
- **DS2 窗口切换**: `Command + `` (反引号) - 在同一应用的窗口间切换
- **CT2 应用切换**: `Command + Tab` - 在所有应用间切换
- **释放修饰键**: 完成切换并激活选中的窗口/应用
- **ESC 键**: 取消切换，返回原始状态

### 高级技巧
- **连续切换**: 按住修饰键，重复按触发键快速浏览
- **反向切换**: 添加 Shift 键进行反向遍历
- **鼠标选择**: 切换界面显示时可以直接点击选择
- **自定义快捷键**: 在偏好设置中配置个性化快捷键组合

### 智能标题策略
DevSwitcher2 提供三种标题提取策略：

1. **优先部分**: 显示标题的前半部分（适合文件名在前的应用）
2. **末尾部分**: 显示标题的后半部分（适合应用名在后的窗口）
3. **自定义分隔符**: 根据指定分隔符智能提取（如 " - ", " | " 等）

## ⚙️ 配置详解

### 快捷键设置
- **修饰键**: Command, Option, Control, Shift 及其组合
- **触发键**: 字母、数字、功能键、特殊符号键
- **冲突检测**: 自动检测并提示快捷键冲突

### 应用特定配置
为不同应用配置个性化的标题提取规则：
- Bundle ID 识别
- 自定义分隔符
- 特定的标题格式处理

### 语言设置
- **系统默认**: 跟随系统语言设置
- **英文**: English interface
- **中文**: 简体中文界面
- 更改后重启生效

## 🛠 开发指南

### 技术架构
- **UI框架**: SwiftUI + AppKit 混合开发
- **权限管理**: Accessibility API
- **事件处理**: Carbon Event Manager
- **图标缓存**: 自定义缓存系统
- **国际化**: NSLocalizedString + 动态语言切换

### 项目结构
```
DevSwitcher2/
├── DevSwitcher2App.swift       # 应用入口和 AppDelegate
├── WindowManager.swift         # 窗口管理核心逻辑
├── HotkeyManager.swift         # 快捷键注册和处理
├── SwitcherComponents.swift    # 切换器 UI 组件
├── PreferencesView.swift       # 偏好设置界面
├── SettingsManager.swift       # 设置存储和管理
├── LocalizationHelper.swift    # 国际化支持
├── AppIconCache.swift          # 图标缓存系统
└── WindowSwitcherView.swift    # 窗口切换视图
```

### 构建要求
- Xcode 15.0+
- Swift 5.9+
- macOS Deployment Target: 13.0

### 参与贡献
1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request


## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。
