import SwiftUI

struct SetReminderSheet: View {
    let userId: String
    let peptideId: String
    let peptideName: String
    let defaultDoseAmountMcg: Double
    @Environment(\.dismiss) var dismiss

    @State private var frequency: DoseFrequency = .daily
    @State private var doseAmount: String = ""
    @State private var doseUnit: DoseUnit = .mcg
    @State private var injectionTime: Date = {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var isSaving = false

    private var scheduleRepo: ScheduleRepository { ScheduleRepository(userId: userId) }
    private var canSave: Bool { (Double(doseAmount) ?? 0) > 0 && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(DoseFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                } header: {
                    Text("How often")
                }

                Section {
                    HStack {
                        TextField("Amount", text: $doseAmount)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases) { u in Text(u.label).tag(u) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 140)
                    }
                } header: {
                    Text("Dose per injection")
                }

                Section {
                    DatePicker("Time", selection: $injectionTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Reminder time")
                }
            }
            .navigationTitle("Remind me to inject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            doseAmount = String(format: "%.0f", defaultDoseAmountMcg)
        }
    }

    private func save() {
        guard let dose = Double(doseAmount), dose > 0 else { return }
        isSaving = true
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: injectionTime)
        let timeSeconds = (comps.hour ?? 8) * 3600 + (comps.minute ?? 0) * 60

        Task {
            // Deactivate any existing active schedules for this peptide
            let existing = (try? await scheduleRepo.fetchActive()) ?? []
            for sched in existing where sched.peptideId == peptideId {
                var updated = sched
                updated.isActive = false
                try? await scheduleRepo.update(updated)
            }

            let sched = Schedule(
                peptideId: peptideId,
                doseAmount: dose,
                doseUnit: doseUnit,
                frequency: frequency,
                timeOfDaySeconds: timeSeconds,
                startDate: Date(),
                endDate: nil,
                isActive: true,
                notificationIds: []
            )
            if let schedId = try? await scheduleRepo.add(sched) {
                var newSched = sched
                newSched.id = schedId
                let slots = NotificationService.slotsPerPeptide(activePeptideCount: 1)
                let ids = await NotificationService.schedule(for: newSched, peptideName: peptideName, slotsPerPeptide: slots)
                try? await scheduleRepo.updateNotificationIds(ids, for: schedId)
            }
            dismiss()
        }
    }
}
