//
//  Color+Hex.swift
//  ClaudeUsage
//
//  Color 扩展 - 支持十六进制颜色值初始化
//

import SwiftUI

extension Color {
    /// 使用十六进制整数创建颜色
    /// - Parameter hex: 十六进制颜色值，例如 0xD97706
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
