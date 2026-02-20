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
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - 用量数据

    /// 获取当前用量数据
    /// - Returns: 用量响应数据
    func fetchUsage() async throws -> UsageResponse {
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
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

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
