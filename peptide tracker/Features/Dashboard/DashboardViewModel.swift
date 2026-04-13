import Foundation
import FirebaseFirestore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var activeVials: [ActiveVial] = []
    @Published var stock: [PeptideStock] = []
    @Published var schedules: [Schedule] = []
    @Published var isLoading = true

    private let peptideRepo: PeptideRepository
    private let vialRepo: VialRepository
    private let stockRepo: StockRepository
    private let scheduleRepo: ScheduleRepository
    private var listeners: [ListenerRegistration] = []

    init(
        peptideRepo: PeptideRepository,
        vialRepo: VialRepository,
        stockRepo: StockRepository,
        scheduleRepo: ScheduleRepository
    ) {
        self.peptideRepo = peptideRepo
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        self.scheduleRepo = scheduleRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(vialRepo.listen { [weak self] in self?.activeVials = $0 })
        listeners.append(stockRepo.listen { [weak self] in self?.stock = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in
            self?.schedules = $0
            self?.isLoading = false
        })
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func daysOfSupply(for peptide: Peptide) -> Double? {
        guard let schedule = schedules.first(where: { $0.peptideId == peptide.id && $0.isActive }) else { return nil }
        let totalStockMcg = stock
            .filter { $0.peptideId == peptide.id }
            .reduce(0.0) { $0 + Double($1.quantityOnHand) * $1.mgPerVial * 1000 }
        let dosesPerDay: Double
        switch schedule.frequency {
        case .daily: dosesPerDay = 1
        case .eod: dosesPerDay = 0.5
        case .threeTimesWeek: dosesPerDay = 3.0 / 7.0
        }
        let dailyMcg = schedule.doseAmount * dosesPerDay
        guard dailyMcg > 0 else { return nil }
        return totalStockMcg / dailyMcg
    }

    func activeVial(for peptide: Peptide) -> ActiveVial? {
        activeVials.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }
}
