import Foundation
import UserNotifications

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func scheduleReminder(title: String, body: String? = nil, at date: Date, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do { try await UNUserNotificationCenter.current().add(request) } catch {}
    }

    func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}


