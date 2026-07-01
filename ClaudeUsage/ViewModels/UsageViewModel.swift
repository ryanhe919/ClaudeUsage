//
//  UsageViewModel.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import Foundation
import SwiftUI
import Combine

/// 主 ViewModel，管理用量数据和应用状态
@MainActor
final class UsageViewModel: ObservableObject {

    // MARK: - 发布属性

    @Published var usageResponse: UsageResponse?
    @Published var usageSummary: UsageSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConfigured = false
    @Published var lastRefreshTime: Date?
    @Published var refreshInterval: TimeInterval = 300
    /// 是否正在使用本地 Claude Code 登录（而非手动 Cookie）
    @Published var usingClaudeCodeLogin = false

    // MARK: - 私有属性

    private var refreshTask: Task<Void, Never>?
    private let refreshIntervalKey = "claude_refresh_interval"

    // MARK: - 初始化

    init() {
        let saved = UserDefaults.standard.double(forKey: refreshIntervalKey)
        if saved > 0 {
            refreshInterval = saved
        }

        Task {
            NotificationManager.shared.requestPermission()
            syncConfigurationState()
            if isConfigured {
                startAutoRefresh()
                // 首次启动时加载数据
                if usageSummary == nil {
                    await refreshUsage()
                }
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - 配置管理

    /// 仅检查凭据是否存在，不触发网络请求
    func syncConfigurationState() {
        // 优先检测本地 Claude Code 登录（读钥匙串，首次会弹一次授权框）
        let hasClaudeCode = ClaudeCodeCredentials.isAvailable
        usingClaudeCodeLogin = hasClaudeCode

        let hasCookie = CookieManager.shared.hasCookie
        let hasOrgID = CookieManager.shared.hasOrganizationID
        // Claude Code 登录可用时无需手动 Cookie / orgID
        isConfigured = hasClaudeCode || (hasCookie && hasOrgID)
    }

    /// 从完整 Cookie 字符串中提取凭据、保存并验证连接
    @discardableResult
    func configureAndValidate(fullCookie: String) async -> Bool {
        errorMessage = nil

        // 从完整 cookie 中提取 sessionKey 和 lastActiveOrg
        let sessionKey = CookieManager.shared.extractSessionKey(from: fullCookie)
        let orgID = CookieManager.shared.extractOrganizationID(from: fullCookie)

        guard let sessionKey, !sessionKey.isEmpty else {
            errorMessage = L("error.sessionKeyNotFound")
            return false
        }
        guard let orgID, !orgID.isEmpty else {
            errorMessage = L("error.orgIDNotFound")
            return false
        }

        do {
            try CookieManager.shared.saveCookie(sessionKey)
            try CookieManager.shared.saveOrganizationID(orgID)
        } catch {
            errorMessage = L("error.saveFailed", error.localizedDescription)
            return false
        }

        syncConfigurationState()

        guard isConfigured else {
            errorMessage = L("error.configFailed")
            return false
        }

        // 尝试获取数据来验证
        await refreshUsage()

        let success = errorMessage == nil
        if success {
            startAutoRefresh()
        }
        return success
    }

    /// 清除所有凭据
    func logout() {
        try? CookieManager.shared.clearAll()
        isConfigured = false
        usageSummary = nil
        usageResponse = nil
        errorMessage = nil
        stopAutoRefresh()
        NotificationManager.shared.resetThresholds()
    }

    // MARK: - 数据刷新

    func refreshUsage() async {
        guard isConfigured else {
            errorMessage = L("error.needCookie")
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await ClaudeAPIService.shared.fetchUsage()
            usageResponse = response
            let summary = buildSummary(from: response)
            usageSummary = summary
            lastRefreshTime = Date()

            // 检查阈值通知
            NotificationManager.shared.checkAndNotify(
                fiveHourUtilization: response.fiveHour?.utilization ?? 0,
                sevenDayUtilization: response.sevenDay?.utilization ?? 0
            )
        } catch let error as ClaudeAPIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = L("error.refreshFailed", error.localizedDescription)
        }

        isLoading = false
    }

    func fetchUsage() async {
        await refreshUsage()
    }

    // MARK: - 自动刷新

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.refreshInterval
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self.refreshUsage()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        guard interval >= 5 else { return }
        refreshInterval = interval
        UserDefaults.standard.set(interval, forKey: refreshIntervalKey)
        if isConfigured {
            startAutoRefresh()
        }
    }

    // MARK: - 菜单栏

    var statusText: String {
        guard let summary = usageSummary else {
            return isConfigured ? "..." : "--"
        }
        return summary.percentageText
    }

    // MARK: - UI 便捷属性

    /// 主要用量百分比（5小时窗口, 0.0-1.0）
    var primaryPercentage: Double {
        usageSummary?.primaryPercentage ?? 0
    }

    /// 5 小时用量
    var fiveHourUtilization: Double {
        usageResponse?.fiveHour?.utilization ?? usageSummary?.fiveHourUtilization ?? 0
    }

    /// 7 天用量
    var sevenDayUtilization: Double {
        usageResponse?.sevenDay?.utilization ?? usageSummary?.sevenDayUtilization ?? 0
    }

    // MARK: - 私有方法

    private func buildSummary(from response: UsageResponse) -> UsageSummary {
        UsageSummary(
            fiveHourUtilization: response.fiveHour?.utilization ?? 0,
            fiveHourResetTimestamp: response.fiveHour?.resetDate?.timeIntervalSince1970,
            sevenDayUtilization: response.sevenDay?.utilization ?? 0,
            sevenDayResetTimestamp: response.sevenDay?.resetDate?.timeIntervalSince1970,
            sevenDayOpusUtilization: response.sevenDayOpus?.utilization,
            sevenDaySonnetUtilization: response.sevenDaySonnet?.utilization,
            lastUpdated: Date().timeIntervalSince1970
        )
    }
}
