import SwiftUI

struct ReconstitutionView: View {
    @StateObject var viewModel: ReconstitutionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bacteriostatic Water").font(.headline).foregroundColor(.white)
                        HStack {
                            TextField("mL", text: $viewModel.bacWaterML)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: viewModel.bacWaterML) { _, _ in viewModel.recalculate() }
                            Text("mL").foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Results
                    if let result = viewModel.result {
                        VStack(spacing: 12) {
                            calcRow(label: "Concentration", value: "\(result.concentrationMcgPerML, specifier: "%.0f") mcg/mL")
                            calcRow(label: "Draw per dose", value: "\(result.drawVolumeML, specifier: "%.3f") mL")
                            calcRow(label: "Syringe units (100u)", value: "\(result.syringeUnits, specifier: "%.1f") units")
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)

                        // Editable doses
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Initial doses (editable)").font(.headline).foregroundColor(.white)
                            TextField("Doses", text: $viewModel.confirmedDoses)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)
                    }

                    Button("Confirm Reconstitution") {
                        Task {
                            try? await viewModel.confirmReconstitution()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.result == nil || viewModel.confirmedDoses.isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle("Open Vial — \(viewModel.peptide.name)")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func calcRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
    }
}
