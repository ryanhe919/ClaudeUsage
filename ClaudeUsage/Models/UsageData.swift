//
//  UsageData.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import Foundation

// MARK: - API 响应模型（匹配真实 API 格式）

/// Claude Usage API 响应
/// GET https://claude.ai/api/organizations/{orgId}/usage
struct UsageResponse {
    /// 5 小时滑动窗口用量（主要限流指标）
    let fiveHour: UsageWindow?
    /// 7 天总用量
    let sevenDay: UsageWindow?
    /// 7 天 OAuth 应用用量
    let sevenDayOauthApps: UsageWindow?
    /// 7 天 Opus 模型用量
    let sevenDayOpus: UsageWindow?
    /// 7 天 Sonnet 模型用量
    let sevenDaySonnet: UsageWindow?
    /// 7 天协作用量
    let sevenDayCowork: UsageWindow?
    /// 内部指标
    let iguanaNecktie: UsageWindow?
    /// 额外用量
    let extraUsage: ExtraUsage?
}

// MARK: - Sendable conformance
extension UsageResponse: Sendable {}

// MARK: - Codable conformance (nonisolated)
extension UsageResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try container.decodeIfPresent(UsageWindow.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDay)
        sevenDayOauthApps = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOauthApps)
        sevenDayOpus = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDaySonnet)
        sevenDayCowork = try container.decodeIfPresent(UsageWindow.self, forKey: .sevenDayCowork)
        iguanaNecktie = try container.decodeIfPresent(UsageWindow.self, forKey: .iguanaNecktie)
        extraUsage = try container.decodeIfPresent(ExtraUsage.self, forKey: .extraUsage)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fiveHour, forKey: .fiveHour)
        try container.encodeIfPresent(sevenDay, forKey: .sevenDay)
        try container.encodeIfPresent(sevenDayOauthApps, forKey: .sevenDayOauthApps)
        try container.encodeIfPresent(sevenDayOpus, forKey: .sevenDayOpus)
        try container.encodeIfPresent(sevenDaySonnet, forKey: .sevenDaySonnet)
        try container.encodeIfPresent(sevenDayCowork, forKey: .sevenDayCowork)
        try container.encodeIfPresent(iguanaNecktie, forKey: .iguanaNecktie)
        try container.encodeIfPresent(extraUsage, forKey: .extraUsage)
    }
}

// MARK: - 用量窗口

/// 单个用量窗口数据
struct UsageWindow: Sendable {
    /// 使用率百分比（0-100）
    let utilization: Double
    /// 重置时间（ISO 8601 格式），可能为 nil
    let resetsAt: String?

    /// 使用率（0.0 - 1.0）
    var percentage: Double {
        utilization / 100.0
    }

    /// 重置时间的 Date 对象
    var resetDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    /// 距离重置的剩余时间描述
    var timeUntilReset: String {
        guard let date = resetDate else { return L("time.unknown") }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return L("time.resettingSoon") }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            let remainHours = hours % 24
            return L("time.daysHours", days, remainHours)
        } else if hours > 0 {
            return L("time.hoursMinutes", hours, minutes)
        } else {
            return L("time.minutes", minutes)
        }
    }
}

// MARK: - Codable conformance
extension UsageWindow: Codable {
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // utilization 可能是 Int 或 Double
        if let doubleVal = try? container.decode(Double.self, forKey: .utilization) {
            utilization = doubleVal
        } else if let intVal = try? container.decode(Int.self, forKey: .utilization) {
            utilization = Double(intVal)
        } else {
            utilization = 0
        }
        resetsAt = try container.decodeIfPresent(String.self, forKey: .resetsAt)
    }
}

// MARK: - 额外用量

struct ExtraUsage: Sendable {
    let utilization: Double?
    let resetsAt: String?
}

extension ExtraUsage: Codable {
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

// MARK: - 用量摘要（用于 UI 展示）

/// 简化的用量数据
struct UsageSummary: Sendable {
    let fiveHourUtilization: Double
    let fiveHourResetTimestamp: TimeInterval?
    let sevenDayUtilization: Double
    let sevenDayResetTimestamp: TimeInterval?
    let sevenDayOpusUtilization: Double?
    let sevenDaySonnetUtilization: Double?
    let lastUpdated: TimeInterval

    var primaryPercentage: Double {
        fiveHourUtilization / 100.0
    }

    var percentageText: String {
        "\(Int(fiveHourUtilization))%"
    }

    var fiveHourResetDate: Date? {
        guard let ts = fiveHourResetTimestamp else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var sevenDayResetDate: Date? {
        guard let ts = sevenDayResetTimestamp else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var lastUpdatedDate: Date {
        Date(timeIntervalSince1970: lastUpdated)
    }
}

// MARK: - API 错误类型

enum ClaudeAPIError: LocalizedError {
    case invalidCookie
    case unauthorized
    case oauthTokenExpired
    case rateLimited
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case unknownError(String)
    case noOrganizationID

    /// 是否为临时性错误（值得自动重试）
    var isTransient: Bool {
        switch self {
        case .rateLimited, .networkError:
            return true
        case .serverError(let code):
            return code >= 500
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidCookie:
            return L("error.invalidCookie")
        case .unauthorized:
            return L("error.unauthorized")
        case .oauthTokenExpired:
            return L("error.oauthExpired")
        case .rateLimited:
            return L("error.rateLimited")
        case .networkError(let error):
            return L("error.network", error.localizedDescription)
        case .decodingError(let error):
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    return L("error.decoding.keyNotFound", key.stringValue, context.codingPath.map(\.stringValue).joined(separator: "."))
                case .typeMismatch(let type, let context):
                    return L("error.decoding.typeMismatch", String(describing: type), context.codingPath.map(\.stringValue).joined(separator: "."))
                case .valueNotFound(let type, let context):
                    return L("error.decoding.valueNotFound", String(describing: type), context.codingPath.map(\.stringValue).joined(separator: "."))
                default:
                    return L("error.decoding.general", error.localizedDescription)
                }
            }
            return L("error.decoding.general", error.localizedDescription)
        case .serverError(let code):
            return L("error.server", code)
        case .unknownError(let message):
            return L("error.unknown", message)
        case .noOrganizationID:
            return L("error.noOrgID")
        }
    }
}
