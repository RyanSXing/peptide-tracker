import SwiftUI

struct ReconstitutionView: View {
    let userId: String
    @StateObject var viewModel: ReconstitutionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showAddCompound = false
    @State private var showSetReminder = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // Compounds list
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Compounds").font(.headline).foregroundColor(.white)
                            Spacer()
                            if !viewModel.availableStocksToAdd.isEmpty {
                                Button {
                                    showAddCompound = true
                                } label: {
                                    Label("Add", systemImage: "plus.circle")
                                        .font(.caption).foregroundColor(.blue)
                                }
                            }
                        }
                        ForEach($viewModel.entries) { $entry in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.peptide.name)
                                        .font(.subheadline).foregroundColor(.white)
                                    Text("\(entry.stock.mgPerVial, specifier: "%.0f") mg vial")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                TextField("mg", text: $entry.mgOverride)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .onChange(of: entry.mgOverride) { _, _ in viewModel.recalculate() }
                                Text("mg").foregroundColor(.secondary).font(.caption)
                                if viewModel.entries.count > 1 {
                                    Button {
                                        viewModel.removeEntry(id: entry.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Bac water input
                    HStack {
                        Text("Bacteriostatic Water").foregroundColor(.secondary)
                        Spacer()
                        TextField("mL", text: $viewModel.bacWaterML)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: viewModel.bacWaterML) { _, _ in viewModel.recalculate() }
                        Text("mL").foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Results per compound
                    if !viewModel.results.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(viewModel.results, id: \.entry.id) { r in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(r.entry.peptide.name)
                                        .font(.subheadline).bold().foregroundColor(.white)
                                    calcRow("Concentration", String(format: "%.0f mcg/mL", r.concentrationMcgPerML))
                                    calcRow("Draw per dose", String(format: "%.3f mL", r.drawVolumeML))
                                    calcRow("Syringe units (100u)", String(format: "%.1f units", r.syringeUnits))
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)

                        // Editable doses
                        HStack {
                            Text("Initial doses").foregroundColor(.secondary)
                            Spacer()
                            TextField("Doses", text: $viewModel.confirmedDoses)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)
                    }

                    Button("Confirm Reconstitution") {
                        Task {
                            try? await viewModel.confirmReconstitution()
                            if viewModel.entries.count == 1 {
                                showSetReminder = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.results.isEmpty || viewModel.confirmedDoses.isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle("Open Vial")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddCompound) {
            AddCompoundSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showSetReminder, onDismiss: { dismiss() }) {
            if let entry = viewModel.entries.first {
                SetReminderSheet(
                    userId: userId,
                    peptideId: entry.peptide.id ?? "",
                    peptideName: entry.peptide.name,
                    defaultDoseAmountMcg: entry.doseAmountMcg
                )
            }
        }
    }

    private func calcRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundColor(.white).bold()
        }
    }
}

struct AddCompoundSheet: View {
    @ObservedObject var viewModel: ReconstitutionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selected: (PeptideStock, Peptide)?

    var body: some View {
        NavigationStack {
            List(viewModel.availableStocksToAdd, id: \.0.id) { stock, peptide in
                Button {
                    selected = (stock, peptide)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peptide.name).foregroundColor(.white)
                            Text(String(format: "%.0f mg · %d vials", stock.mgPerVial, stock.quantityOnHand))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if selected?.0.id == stock.id {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Add Compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let (stock, peptide) = selected {
                            viewModel.addEntry(stock: stock, peptide: peptide)
                            dismiss()
                        }
                    }
                    .disabled(selected == nil)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct BlendReconstitutionView: View {
    @StateObject var viewModel: BlendReconstitutionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Components (read-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Components").font(.headline).foregroundColor(.white)
                        ForEach(viewModel.blend.components, id: \.peptideId) { comp in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comp.peptideName)
                                        .font(.subheadline).foregroundColor(.white)
                                    Text(String(format: "%.1f mg · %.0f mcg default dose", comp.mgAmount, comp.defaultDoseAmountMcg))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // BAC water
                    HStack {
                        Text("Bacteriostatic Water").foregroundColor(.secondary)
                        Spacer()
                        TextField("mL", text: $viewModel.bacWaterML)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: viewModel.bacWaterML) { _, _ in viewModel.recalculate() }
                        Text("mL").foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Results
                    if !viewModel.results.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(viewModel.results, id: \.component.peptideId) { r in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(r.component.peptideName)
                                        .font(.subheadline).bold().foregroundColor(.white)
                                    calcRow("Concentration", String(format: "%.0f mcg/mL", r.concentrationMcgPerML))
                                    calcRow("Draw per dose", String(format: "%.3f mL", r.drawVolumeML))
                                    calcRow("Syringe units (100u)", String(format: "%.1f units", r.syringeUnits))
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)

                        HStack {
                            Text("Initial doses").foregroundColor(.secondary)
                            Spacer()
                            TextField("Doses", text: $viewModel.confirmedDoses)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
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
                    .disabled(viewModel.results.isEmpty || viewModel.confirmedDoses.isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.blend.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func calcRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundColor(.white).bold()
        }
    }
}
