import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class InjectViewModel: ObservableObject {
    @Published var activeVials: [ActiveVial] = []
    @Published var schedules: [Schedule] = []
    @Published var selectedVial: ActiveVial?
    @Published var doseOverrides: [String: String] = [:]  // peptideId → mcg string
    @Published var injectionSite: String = ""
    @Published var isLoading = false

    let preselectedVial: ActiveVial?

    private let vialRepo: VialRepository
    private let logRepo: LogRepository
    private let scheduleRepo: ScheduleRepository
    private let stockRepo: StockRepository
    private var listeners: [ListenerRegistration] = []

    init(
        vialRepo: VialRepository,
        logRepo: LogRepository,
        scheduleRepo: ScheduleRepository,
        stockRepo: StockRepository,
        preselectedVial: ActiveVial? = nil
    ) {
        self.vialRepo = vialRepo
        self.logRepo = logRepo
        self.scheduleRepo = scheduleRepo
        self.stockRepo = stockRepo
        self.preselectedVial = preselectedVial
    }

    func startListening() {
        guard preselectedVial == nil else { return }
        listeners.append(vialRepo.listen { [weak self] vials in
            self?.activeVials = vials
            if self?.selectedVial == nil { self?.selectedVial = vials.first }
        })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    var effectiveVial: ActiveVial? { preselectedVial ?? selectedVial }

    func dose(for compound: VialCompound) -> Double {
        if let s = doseOverrides[compound.peptideId], let d = Double(s), d > 0 { return d }
        return compound.defaultDoseAmountMcg
    }

    var isLastDose: Bool { (effectiveVial?.dosesRemaining ?? 2) <= 1 }

    func deleteVial() async throws {
        guard let vialId = effectiveVial?.id else { return }
        try await vialRepo.delete(vialId: vialId)
    }

    func logInjection() async throws {
        guard let vial = effectiveVial, let vialId = vial.id else { return }
        isLoading = true
        defer { isLoading = false }

        for compound in vial.compounds {
            let log = InjectionLog(
                peptideId: compound.peptideId,
                vialId: vialId,
                doseAmount: dose(for: compound),
                doseUnit: .mcg,
                timestamp: Date(),
                injectionSite: injectionSite.isEmpty ? nil : injectionSite
            )
            try await logRepo.add(log)
        }
        try await vialRepo.decrementDose(vialId: vialId)

        let activeSchedules = schedules.filter(\.isActive)
        for compound in vial.compounds {
            if let sched = activeSchedules.first(where: { $0.peptideId == compound.peptideId }),
               let schedId = sched.id {
                let slots = NotificationService.slotsPerPeptide(activePeptideCount: max(1, activeSchedules.count))
                let ids = await NotificationService.schedule(for: sched, peptideName: compound.peptideName, slotsPerPeptide: slots)
                try await scheduleRepo.updateNotificationIds(ids, for: schedId)
            }
        }
    }
}
