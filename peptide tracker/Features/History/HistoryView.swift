import SwiftUI

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No injections logged yet.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            HalfLifeChartView(
                                peptides: viewModel.peptides,
                                logs: viewModel.logs
                            )
                            .padding(.bottom, 8)

                            ForEach(viewModel.logs) { log in
                                LogRowView(
                                    log: log,
                                    peptideName: viewModel.peptideName(for: log)
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
