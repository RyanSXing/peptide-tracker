import FirebaseFirestore

enum FirestoreSnapshotPolicy {
    static func shouldRenderSnapshot(_ metadata: SnapshotMetadata) -> Bool {
        shouldRenderSnapshot(
            isFromCache: metadata.isFromCache,
            hasPendingWrites: metadata.hasPendingWrites
        )
    }

    static func shouldRenderSnapshot(isFromCache: Bool, hasPendingWrites: Bool) -> Bool {
        !isFromCache || hasPendingWrites
    }
}
