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

    static func hasPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    static func reminderContent(peptideName: String, doseAmount: Double, doseUnit: DoseUnit) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Protocol reminder"
        content.body = "Open Peptide Tracker to review your scheduled entry."
        content.sound = .default
        return content
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
            let content = reminderContent(
                peptideName: peptideName,
                doseAmount: schedule.doseAmount,
                doseUnit: schedule.doseUnit
            )

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
