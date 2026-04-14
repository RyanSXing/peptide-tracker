import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class InjectViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var activeVials: [ActiveVial] = []
    @Published var schedules: [Schedule] = []
    @Published var selectedPeptide: Peptide?
    @Published var doseOverride: String = ""
    @Published var injectionSite: String = ""
    @Published var isLoading = false

    private let peptideRepo: PeptideRepository
    private let vialRepo: VialRepository
    private let logRepo: LogRepository
    private let scheduleRepo: ScheduleRepository
    private var listeners: [ListenerRegistration] = []

    init(
        peptideRepo: PeptideRepository,
        vialRepo: VialRepository,
        logRepo: LogRepository,
        scheduleRepo: ScheduleRepository
    ) {
        self.peptideRepo = peptideRepo
        self.vialRepo = vialRepo
        self.logRepo = logRepo
        self.scheduleRepo = scheduleRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] p in
            self?.peptides = p
            if self?.selectedPeptide == nil { self?.selectedPeptide = p.first }
        })
        listeners.append(vialRepo.listen { [weak self] in self?.activeVials = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func activeVial(for peptide: Peptide) -> ActiveVial? {
        activeVials.first { $0.peptideId == peptide.id && $0.isActive }
    }

    var effectiveDose: Double {
        if let override = Double(doseOverride), override > 0 { return override }
        return selectedPeptide.flatMap { schedule(for: $0)?.doseAmount } ?? 0
    }

    var effectiveUnit: DoseUnit {
        selectedPeptide.flatMap { schedule(for: $0)?.doseUnit } ?? .mcg
    }

    func logInjection() async throws {
        guard let peptide = selectedPeptide,
              let peptideId = peptide.id,
              let vial = activeVial(for: peptide),
              let vialId = vial.id else { return }

        isLoading = true
        defer { isLoading = false }

        let log = InjectionLog(
            peptideId: peptideId,
            vialId: vialId,
            doseAmount: effectiveDose,
            doseUnit: effectiveUnit,
            timestamp: Date(),
            injectionSite: injectionSite.isEmpty ? nil : injectionSite
        )
        try await logRepo.add(log)
        try await vialRepo.decrementDose(vialId: vialId)

        if let sched = schedule(for: peptide), let scheduleId = sched.id {
            let slots = NotificationService.slotsPerPeptide(activePeptideCount: max(1, schedules.count))
            let ids = await NotificationService.schedule(for: sched, peptideName: peptide.name, slotsPerPeptide: slots)
            try await scheduleRepo.updateNotificationIds(ids, for: scheduleId)
        }
    }
}
