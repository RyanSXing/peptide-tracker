import Foundation
import FirebaseFirestore

@MainActor
final class ActiveVialsViewModel: ObservableObject {
    @Published var vials: [ActiveVial] = []
    @Published var peptides: [Peptide] = []
    private let vialRepo: VialRepository
    private let peptideRepo: PeptideRepository
    private var listeners: [ListenerRegistration] = []

    init(vialRepo: VialRepository, peptideRepo: PeptideRepository) {
        self.vialRepo = vialRepo
        self.peptideRepo = peptideRepo
    }

    func startListening() {
        listeners.append(vialRepo.listen { [weak self] in self?.vials = $0 })
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptide(for vial: ActiveVial) -> Peptide? {
        peptides.first { $0.id == vial.peptideId }
    }

    func deactivate(_ vial: ActiveVial) async throws {
        var updated = vial
        updated.isActive = false
        try await vialRepo.update(updated)
    }
}
