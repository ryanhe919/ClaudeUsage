//
//  KeychainHelper.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import Foundation
import Security

/// Keychain 安全存储工具，用于安全保存敏感数据（如 Session Cookie）
enum KeychainHelper {

    // MARK: - 存储项标识

    /// Keychain 存储项的 key 定义
    enum Key: String {
        case sessionCookie = "com.time-stone.ClaudeUsage.sessionCookie"
        case organizationID = "com.time-stone.ClaudeUsage.organizationID"
    }

    // MARK: - 错误类型

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return L("keychain.saveFailed", status)
            case .readFailed(let status):
                return L("keychain.readFailed", status)
            case .deleteFailed(let status):
                return L("keychain.deleteFailed", status)
            case .dataConversionFailed:
                return L("keychain.dataConversionFailed")
            }
        }
    }

    // MARK: - 公共接口

    /// 保存字符串到 Keychain
    /// - Parameters:
    ///   - value: 要保存的字符串
    ///   - key: 存储项标识
    static func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // 先尝试删除已有项，忽略错误
        try? delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// 从 Keychain 读取字符串
    /// - Parameter key: 存储项标识
    /// - Returns: 存储的字符串，不存在时返回 nil
    static func read(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// 从 Keychain 删除存储项
    /// - Parameter key: 存储项标识
    static func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// 检查 Keychain 中是否存在指定项
    /// - Parameter key: 存储项标识
    /// - Returns: 是否存在
    static func exists(for key: Key) -> Bool {
        read(for: key) != nil
    }
}
