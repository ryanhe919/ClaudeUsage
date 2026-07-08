//
//  ClaudeAPIService.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import Foundation

/// Claude API 网络请求服务
/// 负责与 Claude API 交互，获取用量数据
actor ClaudeAPIService {

    static let shared = ClaudeAPIService()

    private let baseURL = "https://claude.ai/api"
    /// Claude Code OAuth 令牌可访问的用量端点（未公开，与网页版 /usage 返回同构）
    private let oauthUsageURL = "https://api.anthropic.com/api/oauth/usage"
    private let session: URLSession

    /// 诚实的应用标识 User-Agent（不伪装浏览器，避免被误判为会话劫持）
    private static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "ClaudeUsage/\(version) (macOS; menu-bar usage monitor)"
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - 用量数据

    /// 获取当前用量数据
    ///
    /// 优先使用本地 Claude Code 的 OAuth 登录；不可用时回退到手动 Cookie 方式。
    /// - Returns: 用量响应数据
    func fetchUsage() async throws -> UsageResponse {
        if let token = ClaudeCodeCredentials.currentToken() {
            return try await withRetry { try await self.fetchUsageViaOAuth(token: token) }
        }
        return try await withRetry { try await self.fetchUsageViaCookie() }
    }

    /// 通过 Claude Code 的 OAuth 令牌获取用量
    private func fetchUsageViaOAuth(token: ClaudeCodeCredentials.OAuthToken) async throws -> UsageResponse {
        // 令牌已过期：Claude Code 尚未刷新，直接给出明确提示
        if token.isExpired {
            throw ClaudeAPIError.oauthTokenExpired
        }

        guard let url = URL(string: oauthUsageURL) else {
            throw ClaudeAPIError.unknownError("无效的 URL: \(oauthUsageURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            return try await performRequest(request)
        } catch ClaudeAPIError.unauthorized {
            // OAuth 端点返回 401 → 令牌失效，提示刷新而非“更新 Cookie”
            throw ClaudeAPIError.oauthTokenExpired
        }
    }

    /// 通过手动配置的 Cookie 获取用量
    private func fetchUsageViaCookie() async throws -> UsageResponse {
        let orgID = try await getOrganizationID()
        let url = try buildURL(path: "/organizations/\(orgID)/usage")
        let request = try await buildRequest(url: url)
        return try await performRequest(request)
    }

    // MARK: - 组织信息

    /// 组织信息响应
    struct OrganizationInfo: Codable, Sendable {
        let uuid: String?
        let name: String?
        let planType: String?

        enum CodingKeys: String, CodingKey {
            case uuid
            case name
            case planType = "plan_type"
        }
    }

    /// 获取组织列表
    /// - Returns: 组织信息数组
    func fetchOrganizations() async throws -> [OrganizationInfo] {
        let url = try buildURL(path: "/organizations")
        let request = try await buildRequest(url: url)
        return try await performRequest(request)
    }

    // MARK: - 重试

    /// 对临时性错误（429 / 5xx / 网络抖动）做带退避的自动重试。
    /// 认证类错误（401/403、令牌过期）不重试，直接抛出。
    private func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch let error as ClaudeAPIError where error.isTransient {
                lastError = error
                // 退避: 0.5s, 1s, ...（最后一次失败不再等待）
                if attempt < maxAttempts - 1 {
                    let delay = UInt64(0.5 * Double(1 << attempt) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError ?? ClaudeAPIError.unknownError("重试失败")
    }

    // MARK: - 内部方法

    /// 构建完整 URL
    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw ClaudeAPIError.unknownError("无效的 URL: \(baseURL + path)")
        }
        return url
    }

    /// 构建带认证的请求
    private func buildRequest(url: URL) async throws -> URLRequest {
        // 从 MainActor 获取 cookie
        let cookieValue = await MainActor.run {
            CookieManager.shared.getSessionKey()
        }
        
        guard let cookieValue else {
            throw ClaudeAPIError.invalidCookie
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        return request
    }

    /// 获取 Organization ID，优先使用已保存的
    private func getOrganizationID() async throws -> String {
        // 从 MainActor 获取 orgID
        let orgID = await MainActor.run {
            CookieManager.shared.getOrganizationID()
        }
        
        if let orgID {
            return orgID
        }
        throw ClaudeAPIError.noOrganizationID
    }

    /// 执行网络请求并解码响应
    private func performRequest<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(error)
        }

        // 检查 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.unknownError("非 HTTP 响应")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw ClaudeAPIError.unauthorized
        case 429:
            throw ClaudeAPIError.rateLimited
        case 400...499:
            throw ClaudeAPIError.serverError(httpResponse.statusCode)
        case 500...599:
            throw ClaudeAPIError.serverError(httpResponse.statusCode)
        default:
            throw ClaudeAPIError.serverError(httpResponse.statusCode)
        }

        // 解码 JSON
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let decodingError {
            // 打印原始响应便于调试
            let rawBody = String(data: data, encoding: .utf8) ?? "(non-UTF8 data)"
            print("[ClaudeAPI] Decoding failed: \(decodingError)")
            print("[ClaudeAPI] Raw response: \(rawBody.prefix(2000))")
            throw ClaudeAPIError.decodingError(decodingError)
        }
    }
}
