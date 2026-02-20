//
//  NotificationManager.swift
//  ClaudeUsage
//
//  用量阈值通知管理
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let notificationEnabledKey = "notificationsEnabled"
    private let thresholds: [Double] = [50, 70, 90, 100]

    // 记录每种用量已通知的最高阈值
    private var lastNotifiedThreshold: [String: Double] = [:]

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: notificationEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: notificationEnabledKey) }
    }

    private init() {}

    /// 请求通知权限
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Notification] Permission error: \(error)")
            }
        }
    }

    /// 检查用量并在跨过阈值时发送通知
    /// - Parameters:
    ///   - fiveHourUtilization: 5小时用量百分比 (0-100)
    ///   - sevenDayUtilization: 7天用量百分比 (0-100)
    func checkAndNotify(fiveHourUtilization: Double, sevenDayUtilization: Double) {
        guard isEnabled else { return }

        checkThreshold(utilization: fiveHourUtilization, category: "fiveHour",
                       titleKey: "notification.fiveHour.title")
        checkThreshold(utilization: sevenDayUtilization, category: "sevenDay",
                       titleKey: "notification.sevenDay.title")
    }

    private func checkThreshold(utilization: Double, category: String, titleKey: String) {
        let lastThreshold = lastNotifiedThreshold[category] ?? 0

        // 找到当前用量对应的最高阈值
        let currentThreshold = thresholds.last(where: { utilization >= $0 }) ?? 0

        // 如果用量下降，重置记录（允许再次通知）
        if currentThreshold < lastThreshold {
            lastNotifiedThreshold[category] = currentThreshold
            return
        }

        // 找到需要新通知的阈值（比上次通知的高）
        let newThresholds = thresholds.filter { $0 > lastThreshold && utilization >= $0 }

        if let highest = newThresholds.last {
            sendNotification(titleKey: titleKey, threshold: Int(highest), utilization: Int(utilization))
            lastNotifiedThreshold[category] = highest
        }
    }

    private func sendNotification(titleKey: String, threshold: Int, utilization: Int) {
        let content = UNMutableNotificationContent()
        content.title = L(titleKey)
        content.body = L("notification.body", utilization, threshold)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage-\(titleKey)-\(threshold)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // 立即发送
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 重置所有阈值记录（logout 时调用）
    func resetThresholds() {
        lastNotifiedThreshold.removeAll()
    }
}
