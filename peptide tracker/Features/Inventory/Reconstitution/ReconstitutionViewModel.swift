import Foundation

@MainActor
final class ReconstitutionViewModel: ObservableObject {
    @Published var bacWaterML: String = "2"
    @Published var confirmedDoses: String = ""
    @Published var result: ReconstitutionService.Result?

    let stock: PeptideStock
    let peptide: Peptide
    private let vialRepo: VialRepository
    private let stockRepo: StockRepository

    init(stock: PeptideStock, peptide: Peptide, vialRepo: VialRepository, stockRepo: StockRepository) {
        self.stock = stock
        self.peptide = peptide
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        recalculate()
    }

    func recalculate() {
        guard let ml = Double(bacWaterML), ml > 0 else { result = nil; return }
        result = ReconstitutionService.calculate(
            totalMg: stock.mgPerVial,
            bacWaterML: ml,
            targetDoseMcg: peptide.defaultDoseAmount
        )
        let doses = ReconstitutionService.initialDoses(
            totalMg: stock.mgPerVial,
            targetDoseMcg: peptide.defaultDoseAmount
        )
        confirmedDoses = "\(doses)"
    }

    func confirmReconstitution() async throws {
        guard let ml = Double(bacWaterML), ml > 0,
              let calc = result,
              let doses = Int(confirmedDoses),
              let stockId = stock.id else { return }

        let vial = ActiveVial(
            peptideId: stock.peptideId,
            stockId: stockId,
            totalMg: stock.mgPerVial,
            bacWaterML: ml,
            concentrationMcgPerML: calc.concentrationMcgPerML,
            dosesRemaining: doses,
            dateConstituted: Date(),
            estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            isActive: true
        )
        try await vialRepo.add(vial)

        var updated = stock
        updated.quantityOnHand = max(0, stock.quantityOnHand - 1)
        try await stockRepo.update(updated)
    }
}
