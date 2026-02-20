//
//  ClaudeUsageApp.swift
//  ClaudeUsage
//
//  Created by Yufan He on 2026/2/20.
//

import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @State private var localizationManager = LocalizationManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
                .environment(\.locale, localizationManager.currentLocale)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                Text(viewModel.statusText)
                    .monospacedDigit()
            }
            .environment(\.locale, localizationManager.currentLocale)
        }
        .menuBarExtraStyle(.window)
    }
}
