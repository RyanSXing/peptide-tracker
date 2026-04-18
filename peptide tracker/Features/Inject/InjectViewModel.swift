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
    private let blendRepo: BlendRepository
    private var listeners: [ListenerRegistration] = []

    init(
        vialRepo: VialRepository,
        logRepo: LogRepository,
        scheduleRepo: ScheduleRepository,
        stockRepo: StockRepository,
        blendRepo: BlendRepository,
        preselectedVial: ActiveVial? = nil
    ) {
        self.vialRepo = vialRepo
        self.logRepo = logRepo
        self.scheduleRepo = scheduleRepo
        self.stockRepo = stockRepo
        self.blendRepo = blendRepo
        self.preselectedVial = preselectedVial
    }

    func startListening() {
        prefillDosesIfNeeded()
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

    /// Maximum mcg the user can inject right now for this compound (whatever is physically left).
    func maxDoseMcg(for compound: VialCompound) -> Double {
        guard let vial = effectiveVial else { return compound.defaultDoseAmountMcg }
        let dosesUsed = vial.totalDoses - vial.dosesRemaining
        return max(0, compound.mgInVial * 1000.0 - Double(dosesUsed) * compound.defaultDoseAmountMcg)
    }

    func isDoseExceeding(_ compound: VialCompound) -> Bool {
        dose(for: compound) > maxDoseMcg(for: compound) + 0.01
    }

    var anyDoseExceedsVial: Bool {
        effectiveVial?.compounds.contains { isDoseExceeding($0) } ?? false
    }

    /// When one field in a multi-compound vial changes, scale all others by the same ratio.
    func adjustBlendDoses(changedPeptideId: String, newValueStr: String) {
        guard let vial = effectiveVial, vial.compounds.count > 1 else { return }
        guard let changed = vial.compounds.first(where: { $0.peptideId == changedPeptideId }) else { return }
        guard let newDose = Double(newValueStr), newDose > 0, changed.defaultDoseAmountMcg > 0 else { return }
        let ratio = newDose / changed.defaultDoseAmountMcg
        for compound in vial.compounds where compound.peptideId != changedPeptideId {
            doseOverrides[compound.peptideId] = String(format: "%.0f", ratio * compound.defaultDoseAmountMcg)
        }
    }

    var isPartialLastDose: Bool {
        guard isLastDose, let vial = effectiveVial, let first = vial.compounds.first else { return false }
        let dosesUsed = vial.totalDoses - vial.dosesRemaining
        let remainingMcg = first.mgInVial * 1000 - Double(dosesUsed) * first.defaultDoseAmountMcg
        return remainingMcg > 0 && remainingMcg < first.defaultDoseAmountMcg
    }

    private func remainingMcg(for compound: VialCompound) -> Double {
        guard let vial = effectiveVial else { return compound.defaultDoseAmountMcg }
        let dosesUsed = vial.totalDoses - vial.dosesRemaining
        return max(0, compound.mgInVial * 1000 - Double(dosesUsed) * compound.defaultDoseAmountMcg)
    }

    private func prefillDosesIfNeeded() {
        guard let vial = effectiveVial, vial.dosesRemaining == 1 else { return }
        for compound in vial.compounds {
            guard doseOverrides[compound.peptideId] == nil else { continue }
            let remaining = remainingMcg(for: compound)
            if remaining < compound.defaultDoseAmountMcg {
                doseOverrides[compound.peptideId] = String(format: "%.0f", remaining)
            }
        }
    }

    func deleteVial() async throws {
        guard let vialId = effectiveVial?.id else { return }
        try await vialRepo.delete(vialId: vialId)
    }

    /// Returns available stock options for the current single-compound vial.
    /// Returns empty for blends or multi-compound vials (handled separately).
    func availableStocksForVial() async throws -> [PeptideStock] {
        guard let vial = effectiveVial,
              !vial.isBlend,
              vial.compounds.count == 1,
              let compound = vial.compounds.first else { return [] }
        let candidates = try await stockRepo.fetch(for: compound.peptideId)
        return candidates.filter { $0.quantityOnHand > 0 }.sorted { $0.mgPerVial < $1.mgPerVial }
    }

    /// Opens a fresh vial from stock (or blend stock), then deletes the now-empty old vial.
    /// Pass `chosenStock` for single-compound vials when the user has selected a specific size.
    func openNewVial(using chosenStock: PeptideStock? = nil) async throws {
        guard let vial = effectiveVial, let oldId = vial.id else { return }

        if vial.isBlend {
            guard let blend = try await blendRepo.fetch(id: vial.stockId),
                  blend.quantityOnHand > 0 else {
                throw NSError(domain: "", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "\(vial.displayName) blend is out of stock. Restock from Inventory first."])
            }
            let newVial = ActiveVial(
                stockId: vial.stockId,
                compounds: vial.compounds,
                bacWaterML: vial.bacWaterML,
                dosesRemaining: vial.totalDoses,
                totalDoses: vial.totalDoses,
                dateConstituted: Date(),
                estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                isActive: true,
                isBlend: true
            )
            try await vialRepo.add(newVial)
            var updated = blend
            updated.quantityOnHand = max(0, blend.quantityOnHand - 1)
            try await blendRepo.update(updated)

        } else if let stock = chosenStock, let compound = vial.compounds.first, vial.compounds.count == 1 {
            // Single-compound with a user-chosen stock size — recalculate for the new mg amount
            let newMg = stock.mgPerVial
            let conc = (newMg * 1000.0) / vial.bacWaterML
            let newTotalDoses = Int(ceil((newMg * 1000.0) / max(1, compound.defaultDoseAmountMcg)))
            let newCompound = VialCompound(
                peptideId: compound.peptideId,
                peptideName: compound.peptideName,
                mgInVial: newMg,
                concentrationMcgPerML: conc,
                defaultDoseAmountMcg: compound.defaultDoseAmountMcg
            )
            let newVial = ActiveVial(
                stockId: stock.id ?? vial.stockId,
                compounds: [newCompound],
                bacWaterML: vial.bacWaterML,
                dosesRemaining: newTotalDoses,
                totalDoses: newTotalDoses,
                dateConstituted: Date(),
                estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                isActive: true,
                isBlend: false
            )
            try await vialRepo.add(newVial)
            var updated = stock
            updated.quantityOnHand = max(0, stock.quantityOnHand - 1)
            try await stockRepo.update(updated)

        } else {
            // Multi-compound or no explicit choice — auto-pick best available stock per compound
            var stocksToDecrement: [PeptideStock] = []
            for compound in vial.compounds {
                let candidates = try await stockRepo.fetch(for: compound.peptideId)
                let available = candidates.filter { $0.quantityOnHand > 0 }
                guard let stock = available.first(where: { $0.id == vial.stockId }) ?? available.first else {
                    throw NSError(domain: "", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "\(compound.peptideName) is out of stock. Restock from Inventory first."])
                }
                stocksToDecrement.append(stock)
            }
            let newVial = ActiveVial(
                stockId: stocksToDecrement.first?.id ?? vial.stockId,
                compounds: vial.compounds,
                bacWaterML: vial.bacWaterML,
                dosesRemaining: vial.totalDoses,
                totalDoses: vial.totalDoses,
                dateConstituted: Date(),
                estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                isActive: true,
                isBlend: false
            )
            try await vialRepo.add(newVial)
            for var stock in stocksToDecrement {
                stock.quantityOnHand = max(0, stock.quantityOnHand - 1)
                try await stockRepo.update(stock)
            }
        }

        try await vialRepo.delete(vialId: oldId)
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
