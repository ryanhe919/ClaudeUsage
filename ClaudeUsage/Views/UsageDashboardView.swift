//
//  UsageDashboardView.swift
//  ClaudeUsage
//
//  详细用量仪表盘 - 展示所有用量窗口数据
//

import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 14) {
            // 主要指标：5 小时用量大仪表
            if let fiveHour = viewModel.usageResponse?.fiveHour {
                UsageGaugeView(percentage: fiveHour.percentage)
                    .frame(height: 140)

                // 5 小时重置时间
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(L("dashboard.fiveHour.window", fiveHour.timeUntilReset))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                UsageGaugeView(percentage: viewModel.primaryPercentage)
                    .frame(height: 140)
            }

            // 各项用量明细
            usageItemsList

            // 错误信息
            if let error = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - 用量项列表

    @ViewBuilder
    private var usageItemsList: some View {
        VStack(spacing: 6) {
            if let response = viewModel.usageResponse {
                // 5 小时用量
                if let fiveHour = response.fiveHour {
                    UsageRowView(
                        icon: "bolt.fill",
                        label: L("dashboard.fiveHour"),
                        utilization: fiveHour.utilization,
                        resetInfo: fiveHour.timeUntilReset,
                        color: colorFor(fiveHour.percentage)
                    )
                }

                // 7 天用量
                if let sevenDay = response.sevenDay {
                    UsageRowView(
                        icon: "calendar",
                        label: L("dashboard.sevenDay"),
                        utilization: sevenDay.utilization,
                        resetInfo: sevenDay.timeUntilReset,
                        color: colorFor(sevenDay.percentage)
                    )
                }

                // 7 天 Opus
                if let opus = response.sevenDayOpus {
                    UsageRowView(
                        icon: "sparkles",
                        label: L("dashboard.opus"),
                        utilization: opus.utilization,
                        resetInfo: opus.timeUntilReset,
                        color: colorFor(opus.percentage)
                    )
                }

                // 7 天 Sonnet
                if let sonnet = response.sevenDaySonnet {
                    UsageRowView(
                        icon: "wand.and.stars",
                        label: L("dashboard.sonnet"),
                        utilization: sonnet.utilization,
                        resetInfo: sonnet.timeUntilReset,
                        color: colorFor(sonnet.percentage)
                    )
                }

                // 7 天协作
                if let cowork = response.sevenDayCowork {
                    UsageRowView(
                        icon: "person.2.fill",
                        label: L("dashboard.cowork"),
                        utilization: cowork.utilization,
                        resetInfo: cowork.timeUntilReset,
                        color: colorFor(cowork.percentage)
                    )
                }

                // OAuth Apps
                if let oauth = response.sevenDayOauthApps {
                    UsageRowView(
                        icon: "app.badge.fill",
                        label: L("dashboard.oauthApps"),
                        utilization: oauth.utilization,
                        resetInfo: oauth.timeUntilReset,
                        color: colorFor(oauth.percentage)
                    )
                }

                // 额外用量
                if let extra = response.extraUsage, let util = extra.utilization {
                    UsageRowView(
                        icon: "plus.circle.fill",
                        label: L("dashboard.extraUsage"),
                        utilization: util,
                        resetInfo: nil,
                        color: colorFor(util / 100.0)
                    )
                }
            }
        }
    }

    private func colorFor(_ percentage: Double) -> Color {
        switch percentage {
        case ..<0.5: return .green
        case 0.5..<0.8: return Color(hex: 0xD97706)
        default: return .red
        }
    }
}

// MARK: - 单行用量条目

struct UsageRowView: View {
    let icon: String
    let label: String
    let utilization: Double
    let resetInfo: String?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .frame(width: 14)
                    Text(label)
                        .font(.caption)
                }

                Spacer()

                Text("\(Int(utilization))%")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(color)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(0, geo.size.width * CGFloat(min(utilization / 100.0, 1.0))), height: 4)
                        .animation(.easeInOut(duration: 0.5), value: utilization)
                }
            }
            .frame(height: 4)

            // 重置时间
            if let resetInfo {
                HStack {
                    Spacer()
                    Text(L("dashboard.resetIn", resetInfo))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
