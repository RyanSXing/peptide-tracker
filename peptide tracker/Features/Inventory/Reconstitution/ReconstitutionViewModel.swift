import Foundation
import Combine

struct CompoundEntry: Identifiable {
    let id = UUID()
    var stock: PeptideStock
    var peptide: Peptide
    var mgOverride: String

    var effectiveMg: Double { Double(mgOverride) ?? stock.mgPerVial }

    var doseAmountMcg: Double {
        switch peptide.defaultDoseUnit {
        case .mcg: return peptide.defaultDoseAmount
        case .mg:  return peptide.defaultDoseAmount * 1000
        case .iu:  return peptide.defaultDoseAmount
        }
    }
}

@MainActor
final class ReconstitutionViewModel: ObservableObject {
    @Published var bacWaterML: String = "2"
    @Published var confirmedDoses: String = ""
    @Published var entries: [CompoundEntry] = []

    struct CompoundResult {
        let entry: CompoundEntry
        let concentrationMcgPerML: Double
        let drawVolumeML: Double
        let syringeUnits: Double
    }
    @Published var results: [CompoundResult] = []

    let allPeptides: [Peptide]
    let allStocks: [PeptideStock]
    private let vialRepo: VialRepository
    private let stockRepo: StockRepository

    init(
        primaryStock: PeptideStock,
        primaryPeptide: Peptide,
        allPeptides: [Peptide],
        allStocks: [PeptideStock],
        vialRepo: VialRepository,
        stockRepo: StockRepository
    ) {
        self.allPeptides = allPeptides
        self.allStocks = allStocks
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        entries = [CompoundEntry(
            stock: primaryStock,
            peptide: primaryPeptide,
            mgOverride: String(format: "%.1f", primaryStock.mgPerVial)
        )]
        recalculate()
    }

    func recalculate() {
        guard let ml = Double(bacWaterML), ml > 0 else { results = []; return }
        results = entries.map { entry in
            let conc = (entry.effectiveMg * 1000) / ml
            let draw = entry.doseAmountMcg / conc
            return CompoundResult(
                entry: entry,
                concentrationMcgPerML: conc,
                drawVolumeML: draw,
                syringeUnits: draw * 100
            )
        }
        if let first = entries.first {
            let doses = Int(floor((first.effectiveMg * 1000) / max(1, first.doseAmountMcg)))
            confirmedDoses = "\(max(0, doses))"
        }
    }

    var availableStocksToAdd: [(PeptideStock, Peptide)] {
        let usedIds = Set(entries.compactMap { $0.stock.id })
        return allStocks
            .filter { !usedIds.contains($0.id ?? "") && $0.quantityOnHand > 0 }
            .compactMap { stock -> (PeptideStock, Peptide)? in
                guard let peptide = allPeptides.first(where: { $0.id == stock.peptideId }) else { return nil }
                return (stock, peptide)
            }
    }

    func addEntry(stock: PeptideStock, peptide: Peptide) {
        entries.append(CompoundEntry(
            stock: stock,
            peptide: peptide,
            mgOverride: String(format: "%.1f", stock.mgPerVial)
        ))
        recalculate()
    }

    func removeEntry(id: UUID) {
        guard entries.count > 1 else { return }
        entries.removeAll { $0.id == id }
        recalculate()
    }

    func confirmReconstitution() async throws {
        guard let ml = Double(bacWaterML), ml > 0,
              let doses = Int(confirmedDoses), doses > 0,
              !results.isEmpty else { return }

        let compounds = results.map { r in
            VialCompound(
                peptideId: r.entry.peptide.id ?? "",
                peptideName: r.entry.peptide.name,
                mgInVial: r.entry.effectiveMg,
                concentrationMcgPerML: r.concentrationMcgPerML,
                defaultDoseAmountMcg: r.entry.doseAmountMcg
            )
        }

        let vial = ActiveVial(
            stockId: entries.first?.stock.id ?? "",
            compounds: compounds,
            bacWaterML: ml,
            dosesRemaining: doses,
            totalDoses: doses,
            dateConstituted: Date(),
            estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            isActive: true
        )
        try await vialRepo.add(vial)

        for entry in entries {
            var updated = entry.stock
            updated.quantityOnHand = max(0, entry.stock.quantityOnHand - 1)
            try await stockRepo.update(updated)
        }
    }
}

@MainActor
final class BlendReconstitutionViewModel: ObservableObject {
    @Published var bacWaterML: String = "2"
    @Published var confirmedDoses: String = ""

    struct BlendResult {
        let component: BlendComponent
        let concentrationMcgPerML: Double
        let drawVolumeML: Double
        let syringeUnits: Double
    }
    @Published var results: [BlendResult] = []

    let blend: Blend
    private let vialRepo: VialRepository
    private let blendRepo: BlendRepository

    init(blend: Blend, vialRepo: VialRepository, blendRepo: BlendRepository) {
        self.blend = blend
        self.vialRepo = vialRepo
        self.blendRepo = blendRepo
        recalculate()
    }

    func recalculate() {
        guard let ml = Double(bacWaterML), ml > 0 else { results = []; return }
        results = blend.components.map { comp in
            let conc = (comp.mgAmount * 1000) / ml
            let draw = comp.defaultDoseAmountMcg / max(1, conc)
            return BlendResult(
                component: comp,
                concentrationMcgPerML: conc,
                drawVolumeML: draw,
                syringeUnits: draw * 100
            )
        }
        if let first = blend.components.first {
            let doses = Int(floor((first.mgAmount * 1000) / max(1, first.defaultDoseAmountMcg)))
            confirmedDoses = "\(max(0, doses))"
        }
    }

    func confirmReconstitution() async throws {
        guard let ml = Double(bacWaterML), ml > 0,
              let doses = Int(confirmedDoses), doses > 0,
              !results.isEmpty else { return }

        let compounds = results.map { r in
            VialCompound(
                peptideId: r.component.peptideId,
                peptideName: r.component.peptideName,
                mgInVial: r.component.mgAmount,
                concentrationMcgPerML: r.concentrationMcgPerML,
                defaultDoseAmountMcg: r.component.defaultDoseAmountMcg
            )
        }
        let vial = ActiveVial(
            stockId: blend.id ?? "",
            compounds: compounds,
            bacWaterML: ml,
            dosesRemaining: doses,
            totalDoses: doses,
            dateConstituted: Date(),
            estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            isActive: true,
            isBlend: true
        )
        try await vialRepo.add(vial)
        var updated = blend
        updated.quantityOnHand = max(0, blend.quantityOnHand - 1)
        try await blendRepo.update(updated)
    }
}
