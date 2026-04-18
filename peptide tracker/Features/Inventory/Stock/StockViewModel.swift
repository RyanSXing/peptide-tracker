import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class StockViewModel: ObservableObject {
    @Published var stockItems: [PeptideStock] = []
    @Published var peptides: [Peptide] = []
    @Published var blends: [Blend] = []
    private let stockRepo: StockRepository
    private let peptideRepo: PeptideRepository
    private let blendRepo: BlendRepository
    private var listeners: [ListenerRegistration] = []

    init(stockRepo: StockRepository, peptideRepo: PeptideRepository, blendRepo: BlendRepository) {
        self.stockRepo = stockRepo
        self.peptideRepo = peptideRepo
        self.blendRepo = blendRepo
    }

    func startListening() {
        listeners.append(stockRepo.listen { [weak self] in self?.stockItems = $0 })
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(blendRepo.listen { [weak self] in self?.blends = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptide(for stockItem: PeptideStock) -> Peptide? {
        peptides.first { $0.id == stockItem.peptideId }
    }

    func addStock(_ stock: PeptideStock) async throws {
        try await stockRepo.add(stock)
    }

    func delete(_ stock: PeptideStock) async throws {
        guard let id = stock.id else { return }
        try await stockRepo.delete(id: id)
    }

    func stockCount(for peptide: Peptide) -> Int {
        stockItems.filter { $0.peptideId == peptide.id }.reduce(0) { $0 + $1.quantityOnHand }
    }

    func stocks(for peptide: Peptide) -> [PeptideStock] {
        stockItems.filter { $0.peptideId == peptide.id }
    }

    func availableStocks(for peptide: Peptide) -> [PeptideStock] {
        stockItems.filter { $0.peptideId == peptide.id && $0.quantityOnHand > 0 }
    }

    func primaryStock(for peptide: Peptide) -> PeptideStock? {
        stockItems.first { $0.peptideId == peptide.id && $0.quantityOnHand > 0 }
    }

    var inventoryPeptides: [Peptide] { peptides.filter { !$0.isBlendOnly } }

    func addPeptide(name: String, halfLifeHours: Double, defaultDoseAmount: Double, defaultDoseUnit: DoseUnit) async throws {
        let peptide = Peptide(
            name: name,
            halfLifeHours: halfLifeHours,
            defaultDoseAmount: defaultDoseAmount,
            defaultDoseUnit: defaultDoseUnit,
            createdAt: Date()
        )
        try await peptideRepo.add(peptide)
    }

    func addBlendOnlyPeptide(name: String, halfLifeHours: Double, defaultDoseAmount: Double, defaultDoseUnit: DoseUnit) async throws -> String {
        let peptide = Peptide(
            name: name,
            halfLifeHours: halfLifeHours,
            defaultDoseAmount: defaultDoseAmount,
            defaultDoseUnit: defaultDoseUnit,
            createdAt: Date(),
            isBlendOnly: true
        )
        return try await peptideRepo.add(peptide)
    }

    func updatePeptide(_ peptide: Peptide) async throws {
        try await peptideRepo.update(peptide)
    }

    func deletePeptide(_ peptide: Peptide) async throws {
        guard let id = peptide.id else { return }
        try await peptideRepo.delete(id: id)
    }

    func addBlend(_ blend: Blend) async throws {
        try await blendRepo.add(blend)
    }

    func updateBlend(_ blend: Blend) async throws {
        try await blendRepo.update(blend)
    }

    func deleteBlend(_ blend: Blend) async throws {
        guard let id = blend.id else { return }
        try await blendRepo.delete(id: id)
    }
}
