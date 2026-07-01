//
//  SettingsView.swift
//  ClaudeUsage
//
//  设置视图 - 内嵌在菜单栏弹出窗口中
//

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Bindable var localizationManager = LocalizationManager.shared
    var onDone: () -> Void

    @State private var cookieText: String = ""
    @State private var selectedInterval: TimeInterval = 300
    @State private var didAppear = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var notificationsEnabled: Bool = NotificationManager.shared.isEnabled
    @State private var isValidating: Bool = false
    @State private var validationMessage: String?
    @State private var validationSuccess: Bool = false

    private let intervalOptions: [(String, TimeInterval)] = [
        ("settings.general.interval.5s", 5),
        ("settings.general.interval.30s", 30),
        ("settings.general.interval.1min", 60),
        ("settings.general.interval.5min", 300),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                }
                .buttonStyle(.borderless)

                Text("settings.title")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    authSection
                    Divider()
                    generalSection

                    if viewModel.isConfigured {
                        Divider()
                        logoutSection
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            selectedInterval = viewModel.refreshInterval
            DispatchQueue.main.async {
                didAppear = true
            }
        }
    }

    // MARK: - 认证设置

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("settings.auth.title", systemImage: "lock.shield.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            // 检测到本地 Claude Code 登录时的提示
            if viewModel.usingClaudeCodeLogin {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.auth.claudeCode.detected")
                            .font(.caption.bold())
                        Text("settings.auth.claudeCode.hint")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.usingClaudeCodeLogin
                     ? "settings.auth.cookie.optional"
                     : "settings.auth.cookie")
                    .font(.caption.bold())

                HStack(spacing: 6) {
                    TextField("settings.auth.cookie.placeholder", text: $cookieText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(3...6)

                    Button {
                        if let content = NSPasteboard.general.string(forType: .string) {
                            cookieText = content
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }

                Text("settings.auth.cookie.hint1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("settings.auth.cookie.hint2")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 验证并保存按钮
            Button {
                validateAndSave()
            } label: {
                HStack(spacing: 6) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                    }
                    Text("settings.auth.validate")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0xD97706))
            .disabled(cookieText.isEmpty || isValidating)

            // 验证结果
            if let message = validationMessage {
                HStack(spacing: 4) {
                    Image(systemName: validationSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                    Text(message)
                        .font(.caption2)
                }
                .foregroundStyle(validationSuccess ? .green : .red)
            }
        }
    }

    // MARK: - 常规设置

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("settings.general.title", systemImage: "slider.horizontal.3")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack {
                Text("settings.general.refreshInterval")
                    .font(.caption)
                Spacer()
                Picker("settings.general.refreshInterval", selection: $selectedInterval) {
                    ForEach(intervalOptions, id: \.1) { option in
                        Text(LocalizedStringKey(option.0)).tag(option.1)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
                .onChange(of: selectedInterval) { _, newValue in
                    guard didAppear else { return }
                    viewModel.updateRefreshInterval(newValue)
                }
            }

            HStack {
                Text("settings.general.launchAtLogin")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if newValue {
                            do {
                                try SMAppService.mainApp.register()
                            } catch {
                                launchAtLogin = false
                            }
                        } else {
                            Task {
                                do {
                                    try await SMAppService.mainApp.unregister()
                                } catch {
                                    launchAtLogin = true
                                }
                            }
                        }
                    }
            }

            HStack {
                Text("settings.general.notifications")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        NotificationManager.shared.isEnabled = newValue
                    }
            }

            HStack {
                Text("settings.general.language")
                    .font(.caption)
                Spacer()
                Picker("settings.general.language", selection: $localizationManager.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }

    // MARK: - 退出登录

    private var logoutSection: some View {
        Button(role: .destructive) {
            viewModel.logout()
            cookieText = ""
            validationMessage = nil
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.caption)
                Text("settings.logout")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - 验证

    private func validateAndSave() {
        isValidating = true
        validationMessage = nil

        Task {
            let success = await viewModel.configureAndValidate(fullCookie: cookieText)

            isValidating = false

            if success {
                validationSuccess = true
                validationMessage = L("settings.auth.success")
                try? await Task.sleep(for: .seconds(1.5))
                onDone()
            } else {
                validationSuccess = false
                validationMessage = viewModel.errorMessage ?? L("settings.auth.failure")
            }
        }
    }
}
