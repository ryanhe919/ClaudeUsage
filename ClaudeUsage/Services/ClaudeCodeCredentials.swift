//
//  ClaudeCodeCredentials.swift
//  ClaudeUsage
//
//  读取本地 Claude Code CLI 存储在 macOS 钥匙串中的 OAuth 凭据。
//  钥匙串条目: service = "Claude Code-credentials"
//  结构: {"claudeAiOauth":{"accessToken":"sk-ant-oat01-...",
//                          "refreshToken":"sk-ant-ort01-...",
//                          "expiresAt": <毫秒时间戳>, ...}}
//
//  说明: accessToken 由 Claude Code 自己负责刷新（过期前 5 分钟、或遇 401 时）
//  并写回钥匙串。本 app 每次请求前重新读取，因此只要你平时在使用 Claude Code，
//  令牌就保持新鲜，无需自行实现刷新逻辑。
//

import Foundation
import Security

/// 读取 Claude Code 登录凭据（OAuth 令牌）
///
/// 纯 Keychain 读取，无共享可变状态；标记 `nonisolated` 使其可从任意隔离域
/// （如 `ClaudeAPIService` 这个 actor）安全调用，避免默认 MainActor 隔离带来的编译错误。
nonisolated enum ClaudeCodeCredentials {

    /// Claude Code 在钥匙串中使用的 service 名称
    private static let service = "Claude Code-credentials"

    /// 解析后的 OAuth 令牌
    nonisolated struct OAuthToken: Sendable {
        let accessToken: String
        /// 过期时间；无法解析时为 nil
        let expiresAt: Date?

        /// 令牌是否已过期
        var isExpired: Bool {
            guard let expiresAt else { return false }
            return expiresAt <= Date()
        }
    }

    // MARK: - 钥匙串读取

    /// 从钥匙串读取原始 JSON 字符串
    /// - Returns: 凭据 JSON，不存在或读取失败时返回 nil
    private static func readRawJSON() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    // MARK: - 解析

    /// 钥匙串 JSON 的解码结构
    private struct CredentialsFile: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            /// 毫秒时间戳
            let expiresAt: Double?
        }
        let claudeAiOauth: OAuth
    }

    /// 读取并解析当前 OAuth 令牌
    /// - Returns: 令牌；未登录 Claude Code 或解析失败时返回 nil
    static func currentToken() -> OAuthToken? {
        guard let json = readRawJSON(),
              let data = json.data(using: .utf8),
              let file = try? JSONDecoder().decode(CredentialsFile.self, from: data) else {
            return nil
        }

        let oauth = file.claudeAiOauth
        guard !oauth.accessToken.isEmpty else { return nil }

        // expiresAt 为毫秒时间戳，转换为 Date
        let expiry = oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000.0) }
        return OAuthToken(accessToken: oauth.accessToken, expiresAt: expiry)
    }

    /// 本地是否存在可用的 Claude Code 登录凭据
    static var isAvailable: Bool {
        currentToken() != nil
    }
}
