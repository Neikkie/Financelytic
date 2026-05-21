import Foundation
import SwiftData
import UserNotifications

/// Schedules upcoming/overdue local notifications for scheduled bills.
@MainActor
enum BillNotificationManager {

    /// Ask for notification permission if we haven't yet. Returns true when notifications can be scheduled.
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Schedules day-before, day-of, and day-after-overdue reminders for a bill.
    static func schedule(for transaction: Transaction) async {
        // Only schedule for unpaid bills with a due date in the future.
        guard !transaction.isPaid, let due = transaction.dueDate else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let id = String(describing: transaction.persistentModelID)
        cancel(id: id) // start fresh

        let cal = Calendar.current
        let dueDay = cal.startOfDay(for: due)
        let billName = transaction.name.isEmpty ? transaction.category.rawValue : transaction.name
        let amount = transaction.amount.currencyFormatted

        if let dayBefore = cal.date(byAdding: .day, value: -1, to: dueDay),
           let trigger = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore),
           trigger > Date() {
            scheduleOne(id: "\(id)-day-before",
                        title: "\(billName) due tomorrow",
                        body: "Don't forget — \(amount) is due tomorrow.",
                        at: trigger)
        }

        if let trigger = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dueDay),
           trigger > Date() {
            scheduleOne(id: "\(id)-day-of",
                        title: "\(billName) is due today",
                        body: "Tap to mark this \(amount) bill paid when you can.",
                        at: trigger)
        }

        if let dayAfter = cal.date(byAdding: .day, value: 1, to: dueDay),
           let trigger = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayAfter),
           trigger > Date() {
            scheduleOne(id: "\(id)-overdue",
                        title: "\(billName) is overdue",
                        body: "Your \(amount) bill was due yesterday.",
                        at: trigger)
        }
    }

    /// Cancels all reminders associated with a transaction.
    static func cancel(for transaction: Transaction) {
        let id = String(describing: transaction.persistentModelID)
        cancel(id: id)
    }

    private static func cancel(id: String) {
        let ids = ["\(id)-day-before", "\(id)-day-of", "\(id)-overdue"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func scheduleOne(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
