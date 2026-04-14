import SwiftUI

struct ActiveVialsTabView: View {
    @StateObject var viewModel: ActiveVialsViewModel

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            if viewModel.vials.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No active vials").font(.title2).bold().foregroundColor(.white)
                    Text("Reconstitute a vial from the Stock tab.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.vials) { vial in
                            VialRowView(
                                vial: vial,
                                peptideName: viewModel.peptide(for: vial)?.name ?? "Unknown"
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { try? await viewModel.deactivate(vial) }
                                } label: {
                                    Label("Discard", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .preferredColorScheme(.dark)
    }
}
