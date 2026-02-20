# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClaudeUsage 是一个 macOS 菜单栏应用，用于实时监控和展示 Claude AI API 的使用量。通过 Claude.ai 的 Cookie 认证，定时拉取用量数据并以仪表盘形式在菜单栏展示。

## 构建与运行

- **纯 Xcode 项目**，无 SPM 或第三方依赖
- Xcode 26.2+，Swift 6.0+，macOS 13+（依赖 MenuBarExtra）
- 直接用 Xcode 打开 `ClaudeUsage.xcodeproj` 构建运行
- 需要网络权限（`com.apple.security.network.client`），已在 entitlements 中配置
- 目前无测试 target

## 架构

采用 **MVVM** 模式，Swift Concurrency（async/await + Actor）贯穿全项目：

```
ClaudeUsage/
├── ClaudeUsageApp.swift      # 入口，MenuBarExtra 场景
├── Models/UsageData.swift     # 数据模型（Codable/Sendable）
├── Services/                  # 网络与安全服务层
│   ├── ClaudeAPIService.swift # Actor，API 请求（单例）
│   ├── CookieManager.swift    # @MainActor，Cookie/OrgID 管理（单例）
│   └── KeychainHelper.swift   # 静态 enum，Keychain 存取
├── ViewModels/
│   └── UsageViewModel.swift   # @MainActor，ObservableObject 状态管理
└── Views/
    ├── MenuBarView.swift          # 菜单栏主视图容器
    ├── UsageDashboardView.swift   # 用量仪表盘
    ├── SettingsView.swift         # 设置页面（Cookie 配置、刷新间隔）
    └── Components/                # 可复用 UI 组件
        ├── Color+Hex.swift        # Color 十六进制扩展
        ├── UsageGaugeView.swift   # 圆环进度指示器
        ├── UsageBarView.swift     # 水平进度条
        └── UsageCardView.swift    # 信息卡片
```

## 关键设计决策

- **凭证安全**：Session Cookie 和 Organization ID 均存于 Keychain（`kSecAttrAccessibleWhenUnlocked`），不使用 UserDefaults 存储敏感信息
- **线程安全**：`ClaudeAPIService` 使用 `actor` 隔离；ViewModel 和 CookieManager 标记 `@MainActor`
- **自动刷新**：基于 `Task` 的轮询机制，间隔可配置（默认 5 分钟），持久化在 UserDefaults
- **API 端点**：`https://claude.ai/api/organizations/{orgId}/usage`，使用 Cookie 头认证
- **用量阈值着色**：<50% 绿色，50-80% 橙色，>80% 红色

## 编码规范

- UI 文本使用中文
- 错误信息（`ClaudeAPIError`）提供中文本地化描述
- 所有数据模型实现 `Sendable` 和 `Codable`
- 使用 Swift 结构化并发，避免 GCD
