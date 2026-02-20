//
//  MenuBarView.swift
//  ClaudeUsage
//
//  菜单栏弹出窗口的主视图 - 内嵌设置页，避免 sheet 导致窗口关闭
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: UsageViewModel
    /// 当前页面：仪表盘 / 设置
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(viewModel: viewModel, onDone: {
                    showSettings = false
                })
            } else {
                dashboardContent
            }
        }
        .frame(width: 340)
    }

    // MARK: - 仪表盘内容

    private var dashboardContent: some View {
        VStack(spacing: 14) {
            // 顶部标题栏
            headerView

            if viewModel.isConfigured {
                if viewModel.isLoading && viewModel.usageResponse == nil && viewModel.usageSummary == nil {
                    loadingView
                } else if let errorMsg = viewModel.errorMessage, viewModel.usageResponse == nil && viewModel.usageSummary == nil {
                    errorView(errorMsg)
                } else {
                    UsageDashboardView(viewModel: viewModel)
                }
            } else {
                unconfiguredView
            }

            Divider()
            bottomBar

            if let lastUpdated = viewModel.lastRefreshTime {
                HStack(spacing: 0) {
                    Text("menu.lastUpdate")
                    Text(lastUpdated, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }

    // MARK: - 顶部标题

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0xD97706), Color(hex: 0xF59E0B)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Claude Usage")
                .font(.title2.bold())

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("menu.loading")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - 错误状态

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("menu.retry") {
                Task { await viewModel.fetchUsage() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0xD97706))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - 未配置提示

    private var unconfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("menu.notConfigured.title")
                .font(.headline)

            Text("menu.notConfigured.message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("menu.notConfigured.action") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0xD97706))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.fetchUsage() }
            } label: {
                Label("menu.refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading || !viewModel.isConfigured)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Label("menu.settings", systemImage: "gear")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("menu.quit", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}
