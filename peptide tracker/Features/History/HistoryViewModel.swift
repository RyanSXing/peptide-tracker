import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var logs: [InjectionLog] = []
    @Published var peptides: [Peptide] = []
    @Published var isLoading = false

    private let peptideRepo: PeptideRepository
    private let logRepo: LogRepository
    private var listeners: [ListenerRegistration] = []

    init(peptideRepo: PeptideRepository, logRepo: LogRepository) {
        self.peptideRepo = peptideRepo
        self.logRepo = logRepo
    }

    func startListening() {
        isLoading = true
        listeners.append(peptideRepo.listen { [weak self] p in
            self?.peptides = p
        })
        listeners.append(logRepo.listen(days: 90) { [weak self] in
            self?.logs = $0
            self?.isLoading = false
        })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptideName(for log: InjectionLog) -> String {
        peptides.first { $0.id == log.peptideId }?.name ?? "Unknown"
    }
}
