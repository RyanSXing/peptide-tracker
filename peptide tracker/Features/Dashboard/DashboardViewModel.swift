import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var activeVials: [ActiveVial] = []
    @Published var isLoading = true

    private let vialRepo: VialRepository
    private let stockRepo: StockRepository
    private let blendRepo: BlendRepository
    private var listeners: [ListenerRegistration] = []

    init(vialRepo: VialRepository, stockRepo: StockRepository, blendRepo: BlendRepository) {
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        self.blendRepo = blendRepo
    }

    func startListening() {
        guard listeners.isEmpty else { return }
        listeners.append(vialRepo.listen { [weak self] vials in
            self?.activeVials = vials
            self?.isLoading = false
        })
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func deleteVial(_ vial: ActiveVial) async throws {
        guard let id = vial.id else { return }
        try await vialRepo.delete(vialId: id)
    }

    func quickReconstitute(_ vial: ActiveVial) async throws {
        // Blend-based vial: find the blend and decrement it
        if vial.isBlend {
            guard let blend = try await blendRepo.fetch(id: vial.stockId),
                  blend.quantityOnHand > 0 else {
                let name = vial.displayName
                throw NSError(domain: "", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "\(name) blend is out of stock. Restock from Inventory first."])
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
            return
        }

        // Stock-based vial: find matching stock for each compound
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
            stockId: vial.stockId,
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
}
