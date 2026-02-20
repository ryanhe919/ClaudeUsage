//
//  UsageCardView.swift
//  ClaudeUsage
//
//  信息卡片组件 - 图标 + 标题 + 值的卡片布局
//

import SwiftUI

struct UsageCardView: View {
    /// SF Symbol 图标名
    let icon: String
    /// 标题
    let title: String
    /// 显示值
    let value: String
    /// 主题颜色
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图标 + 标题行
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 值
            Text(value)
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        UsageCardView(
            icon: "message.fill",
            title: "已使用",
            value: "42",
            color: .orange
        )
        UsageCardView(
            icon: "tray.full.fill",
            title: "总额度",
            value: "100",
            color: .blue
        )
    }
    .padding()
    .frame(width: 300)
}
