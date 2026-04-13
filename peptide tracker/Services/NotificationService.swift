import UserNotifications

enum NotificationService {
    /// Max iOS local notification slots
    private static let maxSlots = 64

    /// Request notification permission. Call once on first launch.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Schedule up to `slotsPerPeptide` notifications for a schedule.
    /// Cancels existing notifications for this peptide first.
    /// Returns the notification IDs that were scheduled (save to schedule.notificationIds).
    @discardableResult
    static func schedule(
        for schedule: Schedule,
        peptideName: String,
        slotsPerPeptide: Int = 10
    ) async -> [String] {
        let center = UNUserNotificationCenter.current()

        // Cancel existing
        center.removePendingNotificationRequests(withIdentifiers: schedule.notificationIds)

        let dates = schedule.nextDoseDates(from: Date(), count: slotsPerPeptide)
        var ids: [String] = []

        for date in dates {
            let content = UNMutableNotificationContent()
            content.title = "Time to inject \(peptideName)"
            content.body = "\(schedule.doseAmount) \(schedule.doseUnit.label)"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = "peptide-\(schedule.peptideId)-\(date.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
            ids.append(id)
        }

        return ids
    }

    /// Cancel all pending notifications for given identifiers.
    static func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel all pending notifications for all peptides (use on logout/reset).
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Slot budget per peptide given total active peptide count.
    /// e.g. 2 peptides → 32 slots each (within 64 limit)
    static func slotsPerPeptide(activePeptideCount: Int) -> Int {
        guard activePeptideCount > 0 else { return maxSlots }
        return maxSlots / activePeptideCount
    }
}
