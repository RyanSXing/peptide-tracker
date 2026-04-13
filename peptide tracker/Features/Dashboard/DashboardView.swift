import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView().tint(.blue)
                } else if viewModel.peptides.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "syringe")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Peptides")
                            .font(.title2).bold().foregroundColor(.white)
                        Text("Add a peptide in Settings to get started.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.peptides) { peptide in
                                if let days = viewModel.daysOfSupply(for: peptide), days < 7 {
                                    alertBanner(
                                        text: "\(peptide.name): \(Int(days)) days of stock remaining",
                                        color: .red
                                    )
                                } else if let vial = viewModel.activeVial(for: peptide), vial.isExpired {
                                    alertBanner(
                                        text: "\(peptide.name): active vial may be expired",
                                        color: .orange
                                    )
                                }
                            }

                            ForEach(viewModel.peptides) { peptide in
                                PeptideCard(
                                    peptide: peptide,
                                    vial: viewModel.activeVial(for: peptide),
                                    schedule: viewModel.schedule(for: peptide),
                                    daysOfSupply: viewModel.daysOfSupply(for: peptide)
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private func alertBanner(text: String, color: Color) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(color)
            Text(text).font(.caption).foregroundColor(.white)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1))
        .cornerRadius(8)
    }
}
