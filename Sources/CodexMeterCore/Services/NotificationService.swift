import Foundation
import UserNotifications

public protocol NotificationDelivering: Sendable {
    func deliver(_ decision: NotificationDecision) async -> Bool
}

public actor NotificationService: NotificationDelivering {
    private let injectedCenter: UNUserNotificationCenter?

    public init(center: UNUserNotificationCenter? = nil) {
        self.injectedCenter = center
    }

    public func deliver(_ decision: NotificationDecision) async -> Bool {
        guard let center = notificationCenter(),
              await isAuthorized(center: center) else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = decision.title
        content.body = decision.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codexmeter.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    private func notificationCenter() -> UNUserNotificationCenter? {
        if let injectedCenter {
            return injectedCenter
        }

        guard Bundle.main.bundleIdentifier != nil else {
            return nil
        }
        return .current()
    }

    private func isAuthorized(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
