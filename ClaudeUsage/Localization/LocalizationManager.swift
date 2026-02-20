//
//  LocalizationManager.swift
//  ClaudeUsage
//
//  语言管理 - 支持中英文切换
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L("language.system")
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

@Observable
final class LocalizationManager {
    @MainActor static let shared = LocalizationManager()

    var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "appLanguage")
        }
    }

    init() {
        self.selectedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
    }

    var currentLocale: Locale {
        let lang = AppLanguage(rawValue: selectedLanguage) ?? .system
        switch lang {
        case .system:
            return .current
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: selectedLanguage) ?? .system }
        set { selectedLanguage = newValue.rawValue }
    }

    /// 根据当前语言设置返回对应的本地化 Bundle
    var localizedBundle: Bundle {
        let lang = appLanguage
        if lang == .system {
            return .main
        }
        guard let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

/// 非 View 代码中使用的本地化函数，响应用户语言设置
/// 在 SwiftUI View 中应使用 Text("key") 配合 .environment(\.locale, ...) 替代
func L(_ key: String) -> String {
    let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    let lang = AppLanguage(rawValue: saved) ?? .system
    if lang == .system {
        return NSLocalizedString(key, comment: "")
    }
    guard let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    return NSLocalizedString(key, bundle: bundle, comment: "")
}

/// 带格式化参数的本地化函数
func L(_ key: String, _ args: any CVarArg...) -> String {
    let format = L(key)
    return String(format: format, arguments: args)
}
