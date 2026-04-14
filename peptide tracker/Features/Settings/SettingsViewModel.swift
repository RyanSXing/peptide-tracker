import Foundation
import FirebaseFirestore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var schedules: [Schedule] = []
    @Published var notificationsEnabled: Bool = false
    @Published var isLoading = false

    private let peptideRepo: PeptideRepository
    private let scheduleRepo: ScheduleRepository
    private let userRepo: UserRepository
    private var listeners: [ListenerRegistration] = []

    init(
        peptideRepo: PeptideRepository,
        scheduleRepo: ScheduleRepository,
        userRepo: UserRepository
    ) {
        self.peptideRepo = peptideRepo
        self.scheduleRepo = scheduleRepo
        self.userRepo = userRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
        Task { notificationsEnabled = await NotificationService.requestPermission() }
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func addPeptide(name: String, halfLifeHours: Double, defaultDoseAmount: Double, defaultDoseUnit: DoseUnit) async throws {
        let peptide = Peptide(
            name: name,
            halfLifeHours: halfLifeHours,
            defaultDoseAmount: defaultDoseAmount,
            defaultDoseUnit: defaultDoseUnit
        )
        try await peptideRepo.add(peptide)
    }

    func deletePeptide(_ peptide: Peptide) async throws {
        try await peptideRepo.delete(peptide)
    }

    func saveSchedule(for peptide: Peptide, frequency: DoseFrequency, doseAmount: Double, doseUnit: DoseUnit, timeSeconds: Int) async throws {
        guard let peptideId = peptide.id else { return }
        // Deactivate existing schedules for this peptide
        for sched in schedules where sched.peptideId == peptideId {
            if var updated = Optional(sched) {
                updated.isActive = false
                try await scheduleRepo.update(updated)
            }
        }
        let sched = Schedule(
            peptideId: peptideId,
            frequency: frequency,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
            startDate: Date(),
            timeOfDaySeconds: timeSeconds,
            notificationIds: [],
            isActive: true
        )
        let schedId = try await scheduleRepo.add(sched)
        // Schedule notifications
        var newSched = sched
        newSched.id = schedId
        let slots = NotificationService.slotsPerPeptide(activePeptideCount: max(1, schedules.filter(\.isActive).count + 1))
        let ids = await NotificationService.schedule(for: newSched, peptideName: peptide.name, slotsPerPeptide: slots)
        try await scheduleRepo.updateNotificationIds(ids, for: schedId)
    }
}
