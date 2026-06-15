import AppKit
import UserNotifications

/// Lightweight user feedback. Tries a system notification; falls back to a
/// transient status-bar message via NSAlert-free logging if notifications
/// are unavailable (e.g. unsigned dev builds).
enum Notifier {
    static func show(title: String, body: String) {
        DispatchQueue.main.async {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else {
                    Self.fallback(title: title, body: body)
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                    content: content,
                                                    trigger: nil)
                center.add(request) { error in
                    if error != nil { Self.fallback(title: title, body: body) }
                }
            }
        }
    }

    private static func fallback(title: String, body: String) {
        DispatchQueue.main.async {
            NSLog("LangTool — %@: %@", title, body)
        }
    }
}
