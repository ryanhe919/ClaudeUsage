//
//  UsageGaugeView.swift
//  ClaudeUsage
//
//  圆形用量仪表组件 - 显示用量百分比的环形进度条
//

import SwiftUI

struct UsageGaugeView: View {
    /// 用量百分比 (0.0 - 1.0)
    let percentage: Double

    // 环形进度条的线宽
    private let lineWidth: CGFloat = 14

    // 起始角度（从顶部开始，即 -90 度）
    private let startAngle: Angle = .degrees(-90)

    var body: some View {
        ZStack {
            // 背景环
            Circle()
                .stroke(
                    Color.secondary.opacity(0.15),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // 进度环
            Circle()
                .trim(from: 0, to: CGFloat(min(percentage, 1.0)))
                .stroke(
                    gradientForPercentage,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(startAngle)
                .animation(.easeInOut(duration: 0.8), value: percentage)

            // 中心内容
            VStack(spacing: 4) {
                // 百分比数字
                Text("\(Int(percentage * 100))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(colorForPercentage)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.5), value: Int(percentage * 100))

                Text("%")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("gauge.used")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
    }

    // MARK: - 渐变色

    /// 根据用量百分比返回对应的渐变色
    private var gradientForPercentage: AngularGradient {
        let colors = colorsForPercentage
        return AngularGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startAngle: startAngle,
            endAngle: .degrees(-90 + 360 * min(percentage, 1.0))
        )
    }

    /// 根据用量百分比返回对应的颜色组
    private var colorsForPercentage: [Color] {
        switch percentage {
        case ..<0.5:
            // 低用量：绿色渐变
            return [.green.opacity(0.7), .green]
        case 0.5..<0.8:
            // 中等用量：Claude 品牌色渐变（橙色到琥珀色）
            return [Color(hex: 0xD97706), Color(hex: 0xF59E0B)]
        default:
            // 高用量：红色渐变
            return [.orange, .red]
        }
    }

    /// 根据用量百分比返回对应的主色调
    private var colorForPercentage: Color {
        switch percentage {
        case ..<0.5:
            return .green
        case 0.5..<0.8:
            return Color(hex: 0xD97706)
        default:
            return .red
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        UsageGaugeView(percentage: 0.3)
            .frame(width: 160, height: 160)
        UsageGaugeView(percentage: 0.65)
            .frame(width: 160, height: 160)
        UsageGaugeView(percentage: 0.9)
            .frame(width: 160, height: 160)
    }
    .padding()
}
