import SwiftUI

struct PeptideManagementView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAddPeptide = false

    var body: some View {
        List {
            ForEach(viewModel.peptides) { peptide in
                NavigationLink {
                    ScheduleEditView(viewModel: viewModel, peptide: peptide)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(peptide.name).font(.headline)
                        if let sched = viewModel.schedule(for: peptide) {
                            Text("\(sched.frequency.rawValue) · \(sched.doseAmount, specifier: "%.0f") \(sched.doseUnit.label)")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Text("No schedule").font(.caption).foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { indexSet in
                for i in indexSet {
                    let p = viewModel.peptides[i]
                    Task { try? await viewModel.deletePeptide(p) }
                }
            }
        }
        .navigationTitle("Peptides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddPeptide = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddPeptide) {
            AddPeptideView(viewModel: viewModel)
        }
        .preferredColorScheme(.dark)
    }
}

struct AddPeptideView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var halfLifeHours = ""
    @State private var defaultDose = ""
    @State private var defaultUnit: DoseUnit = .mcg

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name (e.g. BPC-157)", text: $name)
                }
                Section("Pharmacokinetics") {
                    HStack {
                        TextField("Half-life (hours)", text: $halfLifeHours)
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

struct ScheduleEditView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let peptide: Peptide
    @Environment(\.dismiss) var dismiss

    @State private var frequency: DoseFrequency = .daily
    @State private var doseAmount = ""
    @State private var doseUnit: DoseUnit = .mcg
    @State private var scheduleTime = Date()

    var body: some View {
        Form {
            Section("Frequency") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(DoseFrequency.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Dose") {
                HStack {
                    TextField("Amount", text: $doseAmount).keyboardType(.decimalPad)
                    Picker("Unit", selection: $doseUnit) {
                        ForEach(DoseUnit.allCases, id: \.self) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            Section("Time of day") {
                DatePicker("Time", selection: $scheduleTime, displayedComponents: .hourAndMinute)
            }
        }
        .navigationTitle(peptide.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let dose = Double(doseAmount) else { return }
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: scheduleTime)
                    let secs = (comps.hour ?? 8) * 3600 + (comps.minute ?? 0) * 60
                    Task {
                        try? await viewModel.saveSchedule(
                            for: peptide,
                            frequency: frequency,
                            doseAmount: dose,
                            doseUnit: doseUnit,
                            timeSeconds: secs
                        )
                        dismiss()
                    }
                }
                .disabled(doseAmount.isEmpty)
            }
        }
        .onAppear { prefill() }
        .preferredColorScheme(.dark)
    }

    private func prefill() {
        if let sched = viewModel.schedule(for: peptide) {
            frequency = sched.frequency
            doseAmount = "\(Int(sched.doseAmount))"
            doseUnit = sched.doseUnit
            scheduleTime = sched.timeOfDay(on: Date())
        }
    }
}
