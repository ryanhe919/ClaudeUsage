# Claude Usage

一款 macOS 菜单栏应用，用于实时监控 Claude AI API 的使用量。通过 Claude.ai 的 Session Cookie 进行认证，以直观的仪表盘展示各项用量指标。

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能特性

- **菜单栏常驻** — 在 macOS 菜单栏实时显示当前用量百分比，一目了然
- **可视化仪表盘** — 圆环进度指示器 + 水平进度条，直观展示各时间窗口用量
- **多维度追踪** — 5 小时、7 天、Opus、Sonnet、Cowork、OAuth 应用及额外用量全覆盖
- **用量预警** — 使用量达到 50%、70%、90%、100% 时推送原生 macOS 通知
- **安全存储** — Session Cookie 和 Organization ID 全部存入 Keychain，不使用 UserDefaults 存储敏感信息
- **自动刷新** — 可配置轮询间隔（5 秒 / 30 秒 / 1 分钟 / 5 分钟）
- **开机自启** — 支持通过 `SMAppService` 登录时自动启动
- **双语支持** — 完整的中文和英文界面
- **颜色指示** — 绿色（<50%）、橙色（50-80%）、红色（>80%）

## 截图

<!-- 在此添加截图 -->

## 环境要求

- macOS 13.0+
- Xcode 16.0+
- Swift 6.0+
- 有效的 [Claude Pro/Team](https://claude.ai) 订阅

## 安装

### 从源码构建

1. 克隆仓库：

   ```bash
   git clone https://github.com/yourusername/ClaudeUsage.git
   cd ClaudeUsage
   ```

2. 用 Xcode 打开项目：

   ```bash
   open ClaudeUsage.xcodeproj
   ```

3. 构建并运行（`Cmd + R`）。

无任何第三方依赖，纯 Swift + SwiftUI 项目。

## 配置使用

1. 在浏览器中登录 [claude.ai](https://claude.ai)
2. 打开开发者工具（`Cmd + Option + I`）→ **Network** 标签页或 **Application** → **Cookies**
3. 复制完整的 Cookie 字符串（需包含 `sessionKey` 和 `lastActiveOrg`）
4. 从菜单栏打开 Claude Usage → **设置** → 粘贴 Cookie → **验证并保存**

应用会自动从 Cookie 字符串中提取 `sessionKey` 和 `lastActiveOrg`，通过 API 验证后开始获取用量数据。

## 架构

项目采用 **MVVM** 架构模式，配合独立的服务层，全面使用 Swift 结构化并发。

```
ClaudeUsage/
├── ClaudeUsageApp.swift          # 入口，MenuBarExtra 场景
├── Models/
│   └── UsageData.swift           # 数据模型（Codable + Sendable）
├── Services/
│   ├── ClaudeAPIService.swift    # actor — 线程安全的 API 客户端
│   ├── CookieManager.swift       # @MainActor — 凭证管理
│   ├── KeychainHelper.swift      # Keychain 增删查操作
│   └── NotificationManager.swift # @MainActor — 阈值通知
├── ViewModels/
│   └── UsageViewModel.swift      # @MainActor — 可观察状态管理
├── Views/
│   ├── MenuBarView.swift         # 菜单栏弹出窗口容器
│   ├── UsageDashboardView.swift  # 用量仪表盘（进度环 + 进度条）
│   ├── SettingsView.swift        # 设置页面
│   └── Components/
│       ├── Color+Hex.swift       # Color 十六进制扩展
│       ├── UsageGaugeView.swift  # 圆环进度指示器
│       ├── UsageBarView.swift    # 水平进度条
│       └── UsageCardView.swift   # 信息卡片
├── Localization/
│   └── LocalizationManager.swift # 语言管理
├── en.lproj/Localizable.strings
└── zh-Hans.lproj/Localizable.strings
```

### 关键设计决策

| 领域       | 决策                                                                     |
| ---------- | ------------------------------------------------------------------------ |
| **并发**   | `actor` 隔离网络操作，`@MainActor` 约束 UI 逻辑，所有模型实现 `Sendable` |
| **安全**   | 凭证存入 Keychain（`kSecAttrAccessibleWhenUnlocked`），不使用 UserDefaults |
| **轮询**   | 基于 `Task` 的自动刷新，间隔持久化在 UserDefaults                        |
| **API**    | `GET https://claude.ai/api/organizations/{orgId}/usage`，Cookie 头认证   |
| **通知**   | 按阈值追踪避免重复提醒，用量下降时自动重置                               |

## 用量数据

应用追踪 Claude API 返回的以下用量窗口：

| 指标             | 说明                       |
| ---------------- | -------------------------- |
| **5 小时用量**   | 主要限流窗口               |
| **7 天用量**     | 滚动周用量合计             |
| **Opus（7 天）** | Opus 模型 7 天内用量       |
| **Sonnet（7 天）**| Sonnet 模型 7 天内用量    |
| **Cowork（7 天）**| 协作功能 7 天内用量       |
| **OAuth 应用**   | 第三方应用用量             |
| **额外用量**     | 超出标准额度的额外使用量   |

每项指标均显示使用百分比和重置倒计时。

## 本地化

支持语言：

- English
- 简体中文

在 **设置** → **语言** 中切换（跟随系统 / 中文 / English）。

## 参与贡献

欢迎贡献代码！

1. Fork 本仓库
2. 创建功能分支（`git checkout -b feature/amazing-feature`）
3. 提交更改（`git commit -m 'Add amazing feature'`）
4. 推送到分支（`git push origin feature/amazing-feature`）
5. 发起 Pull Request

## 许可证

本项目基于 MIT 许可证开源 — 详见 [LICENSE](LICENSE) 文件。

## 致谢

- 使用 SwiftUI 和 Swift 结构化并发构建
- 使用 [Anthropic](https://anthropic.com) 的 [Claude.ai](https://claude.ai) 用量 API
