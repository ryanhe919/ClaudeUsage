//
//  UsageBarView.swift
//  ClaudeUsage
//
//  线性进度条组件 - 显示用量的水平进度条
//

import SwiftUI

struct UsageBarView: View {
    /// 标签文字
    let label: String
    /// 已用数量
    let used: Int
    /// 总量
    let total: Int
    /// 百分比 (0.0 - 1.0)
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标签行：标签 + 数量
            HStack {
                Text(label)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(used) / \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    // 前景进度
                    Capsule()
                        .fill(gradientForPercentage)
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(min(percentage, 1.0))),
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.6), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - 渐变色

    /// 根据用量百分比返回对应的渐变色
    private var gradientForPercentage: LinearGradient {
        let colors: [Color] = {
            switch percentage {
            case ..<0.5:
                return [.green.opacity(0.8), .green]
            case 0.5..<0.8:
                return [Color(hex: 0xD97706), Color(hex: 0xF59E0B)]
            default:
                return [.orange, .red]
            }
        }()

        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        UsageBarView(label: "消息用量", used: 30, total: 100, percentage: 0.3)
        UsageBarView(label: "消息用量", used: 65, total: 100, percentage: 0.65)
        UsageBarView(label: "消息用量", used: 92, total: 100, percentage: 0.92)
    }
    .padding()
    .frame(width: 300)
}
