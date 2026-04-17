import SwiftUI

struct InjectSheetView: View {
    @StateObject var viewModel: InjectViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showEmptyAlert = false
    @State private var openNewVialError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                VStack(spacing: 20) {
                    if viewModel.effectiveVial == nil && viewModel.activeVials.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "syringe")
                                .font(.system(size: 48)).foregroundColor(.secondary)
                            Text("No active vials")
                                .foregroundColor(.secondary)
                            Text("Open a vial from Inventory first.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Vial picker (only when not pre-selected)
                        if viewModel.preselectedVial == nil && !viewModel.activeVials.isEmpty {
                            Picker("Vial", selection: $viewModel.selectedVial) {
                                ForEach(viewModel.activeVials) { vial in
                                    Text(vial.displayName).tag(Optional(vial))
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }

                        if let vial = viewModel.effectiveVial {
                            VStack(spacing: 12) {
                                // Vial summary
                                HStack {
                                    Text(vial.displayName)
                                        .font(.headline).foregroundColor(.white)
                                    Spacer()
                                    Text("\(vial.dosesRemaining) doses left")
                                        .font(.caption).foregroundColor(vial.dosesRemaining <= 3 ? .orange : .secondary)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                .cornerRadius(12)

                                // Partial dose warning
                                if viewModel.isPartialLastDose {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Partial dose — less than a full amount remains in the vial.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 4)
                                }

                                // Per-compound dose fields
                                ForEach(vial.compounds, id: \.peptideId) { compound in
                                    let exceeds = viewModel.isDoseExceeding(compound)
                                    let maxMcg = viewModel.maxDoseMcg(for: compound)
                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack {
                                            Text(compound.peptideName).foregroundColor(.secondary)
                                            Spacer()
                                            TextField(
                                                String(format: "%.0f", compound.defaultDoseAmountMcg),
                                                text: Binding(
                                                    get: { viewModel.doseOverrides[compound.peptideId] ?? "" },
                                                    set: { val in
                                                        viewModel.doseOverrides[compound.peptideId] = val
                                                        viewModel.adjustBlendDoses(changedPeptideId: compound.peptideId, newValueStr: val)
                                                    }
                                                )
                                            )
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 80)
                                            .foregroundColor(exceeds ? .red : .primary)
                                            Text("mcg").foregroundColor(.secondary)
                                        }
                                        if exceeds {
                                            Text("Max \(String(format: "%.0f", maxMcg)) mcg remaining")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(exceeds ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
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
                                        let lastDose = viewModel.isLastDose
                                        try? await viewModel.logInjection()
                                        if lastDose {
                                            showEmptyAlert = true
                                        } else {
                                            dismiss()
                                        }
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
                                .disabled(vial.dosesRemaining == 0 || viewModel.isLoading || viewModel.anyDoseExceedsVial)
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
                    Button("Cancel") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
        }
        .alert("Vial Empty", isPresented: $showEmptyAlert) {
            Button("Open New Vial") {
                Task {
                    do {
                        try await viewModel.openNewVial()
                        dismiss()
                    } catch {
                        openNewVialError = error.localizedDescription
                    }
                }
            }
            Button("Not Now", role: .cancel) {
                Task { try? await viewModel.deleteVial(); dismiss() }
            }
        } message: {
            Text("You've used the last dose. Open a fresh vial from your stock?")
        }
        .alert("Out of Stock", isPresented: Binding(
            get: { openNewVialError != nil },
            set: { if !$0 { openNewVialError = nil } }
        )) {
            Button("OK", role: .cancel) {
                openNewVialError = nil
                Task { try? await viewModel.deleteVial(); dismiss() }
            }
        } message: {
            Text(openNewVialError ?? "")
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
