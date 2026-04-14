import SwiftUI

struct InjectSheetView: View {
    @StateObject var viewModel: InjectViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                VStack(spacing: 20) {
                    if viewModel.peptides.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "syringe")
                                .font(.system(size: 48)).foregroundColor(.secondary)
                            Text("No peptides set up.")
                                .foregroundColor(.secondary)
                            Text("Add a peptide in Settings first.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Peptide picker
                        Picker("Peptide", selection: $viewModel.selectedPeptide) {
                            ForEach(viewModel.peptides) { p in
                                Text(p.name).tag(Optional(p))
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if let peptide = viewModel.selectedPeptide {
                            VStack(spacing: 16) {
                                // Dose
                                HStack {
                                    Text("Dose").foregroundColor(.secondary)
                                    Spacer()
                                    TextField(
                                        "\(viewModel.effectiveDose, specifier: "%.0f")",
                                        text: $viewModel.doseOverride
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    Text(viewModel.effectiveUnit.label).foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                .cornerRadius(12)

                                // Active vial info
                                if let vial = viewModel.activeVial(for: peptide) {
                                    HStack {
                                        Text("Active vial").foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(vial.dosesRemaining) doses remaining")
                                            .foregroundColor(vial.dosesRemaining <= 3 ? .orange : .green)
                                    }
                                    .padding()
                                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                    .cornerRadius(12)
                                } else {
                                    Text("No active vial — open a vial from Inventory first.")
                                        .font(.caption).foregroundColor(.orange)
                                        .padding()
                                }

                                // Injection site
                                HStack {
                                    Text("Site (optional)").foregroundColor(.secondary)
                                    Spacer()
                                    TextField("e.g. abdomen", text: $viewModel.injectionSite)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                .cornerRadius(12)

                                // Log button
                                Button {
                                    Task {
                                        try? await viewModel.logInjection()
                                        isPresented = false
                                    }
                                } label: {
                                    HStack {
                                        if viewModel.isLoading {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "syringe")
                                            Text("Log Injection")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.activeVial(for: peptide) == nil || viewModel.isLoading)
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Log Injection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
