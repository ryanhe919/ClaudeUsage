//
//  CookieManager.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import Foundation

/// Cookie 和会话管理器
/// 负责存储、检索 Session Cookie 和 Organization ID
@MainActor
final class CookieManager {

    static let shared = CookieManager()

    private init() {}

    // MARK: - Session Cookie 管理

    /// 保存 Session Cookie 到 Keychain
    /// - Parameter cookie: 完整的 cookie 字符串（来自浏览器）
    func saveCookie(_ cookie: String) throws {
        let trimmed = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClaudeAPIError.invalidCookie
        }
        try KeychainHelper.save(trimmed, for: .sessionCookie)

        // 尝试从 cookie 中自动提取 Organization ID
        if let orgID = extractOrganizationID(from: trimmed) {
            try saveOrganizationID(orgID)
        }
    }

    /// 获取已保存的 Session Cookie
    /// - Returns: cookie 字符串，未设置时返回 nil
    func getCookie() -> String? {
        KeychainHelper.read(for: .sessionCookie)
    }

    /// 获取用于请求头的 sessionKey 值
    /// - Returns: 格式化的 cookie 字符串，可直接用于 Cookie header
    func getSessionKey() -> String? {
        guard let cookie = getCookie() else { return nil }

        // 如果用户直接提供了 sessionKey=xxx 格式，直接返回
        if cookie.contains("sessionKey=") {
            return cookie
        }

        // 否则当作纯 sessionKey 值处理
        return "sessionKey=\(cookie)"
    }

    /// 删除已保存的 Cookie
    func deleteCookie() throws {
        try KeychainHelper.delete(for: .sessionCookie)
    }

    /// 检查是否已设置 Cookie
    var hasCookie: Bool {
        KeychainHelper.exists(for: .sessionCookie)
    }

    // MARK: - Organization ID 管理

    /// 保存 Organization ID
    /// - Parameter orgID: 组织 ID
    func saveOrganizationID(_ orgID: String) throws {
        let trimmed = orgID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try KeychainHelper.save(trimmed, for: .organizationID)
    }

    /// 获取已保存的 Organization ID
    /// - Returns: Organization ID，未设置时返回 nil
    func getOrganizationID() -> String? {
        KeychainHelper.read(for: .organizationID)
    }

    /// 检查是否已设置 Organization ID
    var hasOrganizationID: Bool {
        KeychainHelper.exists(for: .organizationID)
    }

    // MARK: - Cookie 解析

    /// 从 cookie 字符串中提取 lastActiveOrg 的值
    /// - Parameter cookie: 完整的 cookie 字符串
    /// - Returns: Organization ID，未找到时返回 nil
    func extractOrganizationID(from cookie: String) -> String? {
        // 按分号分割 cookie 键值对
        let pairs = cookie.components(separatedBy: ";")
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("lastActiveOrg=") {
                let value = trimmed.replacingOccurrences(of: "lastActiveOrg=", with: "")
                let orgID = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return orgID.isEmpty ? nil : orgID
            }
        }
        return nil
    }

    /// 从 cookie 字符串中提取 sessionKey 的值
    /// - Parameter cookie: 完整的 cookie 字符串
    /// - Returns: sessionKey 值
    func extractSessionKey(from cookie: String) -> String? {
        let pairs = cookie.components(separatedBy: ";")
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("sessionKey=") {
                let value = trimmed.replacingOccurrences(of: "sessionKey=", with: "")
                let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return key.isEmpty ? nil : key
            }
        }
        return nil
    }

    // MARK: - 验证

    /// 验证当前 Cookie 是否有效（通过尝试 API 调用）
    /// - Returns: Cookie 是否有效
    func validateCookie() async -> Bool {
        do {
            _ = try await ClaudeAPIService.shared.fetchUsage()
            return true
        } catch {
            return false
        }
    }

    /// 清除所有已保存的凭据
    func clearAll() throws {
        try? KeychainHelper.delete(for: .sessionCookie)
        try? KeychainHelper.delete(for: .organizationID)
    }
}
