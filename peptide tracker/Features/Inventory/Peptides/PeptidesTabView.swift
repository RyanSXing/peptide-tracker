import SwiftUI

struct PeptidesTabView: View {
    @ObservedObject var viewModel: StockViewModel
    let userId: String
    @State private var restockPeptide: Peptide?
    @State private var editPeptide: Peptide?

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            if viewModel.peptides.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No peptides").font(.title2).bold().foregroundColor(.white)
                    Text("Tap + to add your first peptide.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.peptides) { peptide in
                            PeptideInventoryRow(
                                peptide: peptide,
                                stockCount: viewModel.stockCount(for: peptide),
                                onEdit: { editPeptide = peptide },
                                onRestock: { restockPeptide = peptide }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { try? await viewModel.deletePeptide(peptide) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editPeptide = peptide
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $restockPeptide) { peptide in
            AddStockView(viewModel: viewModel, preselectedPeptide: peptide)
        }
        .sheet(item: $editPeptide) { peptide in
            EditPeptideSheet(viewModel: viewModel, peptide: peptide)
        }
    }
}

struct PeptideInventoryRow: View {
    let peptide: Peptide
    let stockCount: Int
    let onEdit: () -> Void
    let onRestock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(peptide.name)
                    .font(.headline).foregroundColor(.white)
                Text(String(format: "%.1fh half-life · %.0f %@ default dose",
                            peptide.halfLifeHours,
                            peptide.defaultDoseAmount,
                            peptide.defaultDoseUnit.label))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stockCount)")
                    .font(.title2).bold()
                    .foregroundColor(stockCount == 0 ? .orange : .white)
                Text("vials")
                    .font(.caption).foregroundColor(.secondary)
            }
            Button(action: onRestock) {
                Text("Restock")
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

struct EditPeptideSheet: View {
    @ObservedObject var viewModel: StockViewModel
    let peptide: Peptide
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var halfLifeHours = ""
    @State private var defaultDose = ""
    @State private var defaultUnit: DoseUnit = .mcg

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. BPC-157", text: $name)
                }
                Section("Pharmacokinetics") {
                    HStack {
                        TextField("Half-life", text: $halfLifeHours)
                            .keyboardType(.decimalPad)
                        Text("hrs").foregroundColor(.secondary)
                    }
                }
                Section("Default dose") {
                    HStack {
                        TextField("Amount", text: $defaultDose)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $defaultUnit) {
                            ForEach(DoseUnit.allCases, id: \.self) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Edit Peptide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty,
                              let hl = Double(halfLifeHours),
                              let dose = Double(defaultDose) else { return }
                        var updated = peptide
                        updated.name = name
                        updated.halfLifeHours = hl
                        updated.defaultDoseAmount = dose
                        updated.defaultDoseUnit = defaultUnit
                        Task {
                            try? await viewModel.updatePeptide(updated)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || halfLifeHours.isEmpty || defaultDose.isEmpty)
                }
            }
        }
        .onAppear {
            name = peptide.name
            halfLifeHours = String(format: "%.1f", peptide.halfLifeHours)
            defaultDose = String(format: "%.0f", peptide.defaultDoseAmount)
            defaultUnit = peptide.defaultDoseUnit
        }
    }
}

struct AddPeptideInventorySheet: View {
    @ObservedObject var viewModel: StockViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var halfLifeHours = ""
    @State private var defaultDose = ""
    @State private var defaultUnit: DoseUnit = .mcg

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. BPC-157", text: $name)
                }
                Section("Pharmacokinetics") {
                    HStack {
                        TextField("Half-life", text: $halfLifeHours)
                            .keyboardType(.decimalPad)
                        Text("hrs").foregroundColor(.secondary)
                    }
                }
                Section("Default dose") {
                    HStack {
                        TextField("Amount", text: $defaultDose)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $defaultUnit) {
                            ForEach(DoseUnit.allCases, id: \.self) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Add Peptide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty,
                              let hl = Double(halfLifeHours),
                              let dose = Double(defaultDose) else { return }
                        Task {
                            try? await viewModel.addPeptide(
                                name: name,
                                halfLifeHours: hl,
                                defaultDoseAmount: dose,
                                defaultDoseUnit: defaultUnit
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || halfLifeHours.isEmpty || defaultDose.isEmpty)
                }
            }
        }
    }
}
