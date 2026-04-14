import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class StockViewModel: ObservableObject {
    @Published var stockItems: [PeptideStock] = []
    @Published var peptides: [Peptide] = []
    private let stockRepo: StockRepository
    private let peptideRepo: PeptideRepository
    private var listeners: [ListenerRegistration] = []

    init(stockRepo: StockRepository, peptideRepo: PeptideRepository) {
        self.stockRepo = stockRepo
        self.peptideRepo = peptideRepo
    }

    func startListening() {
        listeners.append(stockRepo.listen { [weak self] in self?.stockItems = $0 })
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
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
}
