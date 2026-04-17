import SwiftUI

struct InventoryView: View {
    let userId: String
    @StateObject private var viewModel: StockViewModel
    @State private var showAddPeptide = false
    @State private var showAddBlend = false
    @State private var showAddTypeDialog = false
    @State private var restockPeptide: Peptide?
    @State private var editPeptide: Peptide?
    @State private var reconstitutionTarget: (PeptideStock, Peptide)?
    @State private var blendReconTarget: Blend?
    @State private var outOfStockName: String?
    @State private var restockBlend: Blend?

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: StockViewModel(
            stockRepo: StockRepository(userId: userId),
            peptideRepo: PeptideRepository(userId: userId),
            blendRepo: BlendRepository(userId: userId)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                if viewModel.inventoryPeptides.isEmpty && viewModel.blends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pill")
                            .font(.system(size: 48)).foregroundColor(.secondary)
                        Text("No inventory").font(.title2).bold().foregroundColor(.white)
                        Text("Tap + to add a peptide or blend.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    List {
                        if !viewModel.inventoryPeptides.isEmpty {
                            Section("Peptides") {
                                ForEach(viewModel.inventoryPeptides) { peptide in
                                    let count = viewModel.stockCount(for: peptide)
                                    PeptideStockRow(
                                        peptide: peptide,
                                        stockCount: count,
                                        onEdit: { editPeptide = peptide },
                                        onRestock: { restockPeptide = peptide },
                                        onOpenVial: {
                                            if let stock = viewModel.primaryStock(for: peptide) {
                                                reconstitutionTarget = (stock, peptide)
                                            } else {
                                                outOfStockName = peptide.name
                                            }
                                        }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { try? await viewModel.deletePeptide(peptide) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button { editPeptide = peptide } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }

                        if !viewModel.blends.isEmpty {
                            Section("Blends") {
                                ForEach(viewModel.blends) { blend in
                                    BlendRow(
                                        blend: blend,
                                        onOpenVial: {
                                            if blend.quantityOnHand > 0 {
                                                blendReconTarget = blend
                                            } else {
                                                outOfStockName = blend.name
                                            }
                                        },
                                        onAddStock: { restockBlend = blend }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { try? await viewModel.deleteBlend(blend) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddTypeDialog = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddTypeDialog) {
                AddInventoryTypePicker(
                    onPeptide: { showAddTypeDialog = false; showAddPeptide = true },
                    onBlend:   { showAddTypeDialog = false; showAddBlend = true }
                )
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: Binding(
                get: { reconstitutionTarget != nil },
                set: { if !$0 { reconstitutionTarget = nil } }
            )) {
                if let (stock, peptide) = reconstitutionTarget {
                    ReconstitutionView(
                        viewModel: ReconstitutionViewModel(
                            primaryStock: stock,
                            primaryPeptide: peptide,
                            allPeptides: viewModel.peptides,
                            allStocks: viewModel.stockItems,
                            vialRepo: VialRepository(userId: userId),
                            stockRepo: StockRepository(userId: userId)
                        )
                    )
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { blendReconTarget != nil },
                set: { if !$0 { blendReconTarget = nil } }
            )) {
                if let blend = blendReconTarget {
                    BlendReconstitutionView(
                        viewModel: BlendReconstitutionViewModel(
                            blend: blend,
                            vialRepo: VialRepository(userId: userId),
                            blendRepo: BlendRepository(userId: userId)
                        )
                    )
                }
            }
            .sheet(isPresented: $showAddPeptide) {
                AddPeptideInventorySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddBlend) {
                AddBlendSheet(viewModel: viewModel)
            }
            .sheet(item: $restockPeptide) { peptide in
                AddStockView(viewModel: viewModel, preselectedPeptide: peptide)
            }
            .sheet(item: $editPeptide) { peptide in
                EditPeptideSheet(viewModel: viewModel, peptide: peptide)
            }
            .sheet(item: $restockBlend) { blend in
                RestockBlendSheet(viewModel: viewModel, blend: blend)
            }
            .alert("Out of Stock", isPresented: Binding(
                get: { outOfStockName != nil },
                set: { if !$0 { outOfStockName = nil } }
            )) {
                Button("OK", role: .cancel) { outOfStockName = nil }
            } message: {
                Text("\(outOfStockName ?? "") has no vials left. Tap \"Add Stock\" to restock it first.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}

// MARK: - PeptideStockRow (unchanged)
struct PeptideStockRow: View {
    let peptide: Peptide
    let stockCount: Int
    let onEdit: () -> Void
    let onRestock: () -> Void
    let onOpenVial: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(peptide.name)
                        .font(.headline).foregroundColor(.white)
                    Text(String(format: "%.1fh half-life · %.0f %@ default",
                                peptide.halfLifeHours,
                                peptide.defaultDoseAmount,
                                peptide.defaultDoseUnit.label))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(stockCount)")
                        .font(.title2).bold()
                        .foregroundColor(stockCount == 0 ? .orange : .white)
                    Text("vials in stock")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button(action: onRestock) {
                    Text("Add Stock")
                        .font(.caption).bold()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                Button(action: onOpenVial) {
                    Text("Open Vial")
                        .font(.caption).bold()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(stockCount > 0 ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                        .foregroundColor(stockCount > 0 ? .green : .secondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

// MARK: - BlendRow
struct BlendRow: View {
    let blend: Blend
    let onOpenVial: () -> Void
    let onAddStock: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "flask.fill")
                            .font(.caption).foregroundColor(.purple)
                        Text(blend.name)
                            .font(.headline).foregroundColor(.white)
                    }
                    Text(blend.displayComponents)
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(blend.quantityOnHand)")
                        .font(.title2).bold()
                        .foregroundColor(blend.quantityOnHand == 0 ? .orange : .white)
                    Text("vials in stock")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button(action: onAddStock) {
                    Text("Add Stock")
                        .font(.caption).bold()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                Button(action: onOpenVial) {
                    Text("Open Vial")
                        .font(.caption).bold()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(blend.quantityOnHand > 0 ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                        .foregroundColor(blend.quantityOnHand > 0 ? .green : .secondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}

// MARK: - AddBlendSheet
private struct BlendComponentInput: Identifiable {
    let id = UUID()
    var peptideId: String
    var peptideName: String
    var mg: Double
    var defaultDoseAmountMcg: Double
}

struct AddBlendSheet: View {
    @ObservedObject var viewModel: StockViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var components: [BlendComponentInput] = []
    @State private var quantity = "1"
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var showAddFromLibrary = false
    @State private var showCreatePeptide = false

    private var canSave: Bool {
        !name.isEmpty && !components.isEmpty && Int(quantity) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Blend Name") {
                    TextField("e.g. Recovery Stack", text: $name)
                }

                Section {
                    ForEach(components) { comp in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comp.peptideName)
                                    .font(.subheadline).foregroundColor(.primary)
                                Text(String(format: "%.1f mg per vial", comp.mg))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in components.remove(atOffsets: indexSet) }

                    Button {
                        showAddFromLibrary = true
                    } label: {
                        Label("Add from library", systemImage: "plus.circle")
                    }

                    Button {
                        showCreatePeptide = true
                    } label: {
                        Label("Create new peptide", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Components")
                } footer: {
                    if components.isEmpty {
                        Text("Add at least one peptide compound to this blend.")
                    }
                }

                Section("Stock") {
                    HStack {
                        TextField("Quantity on hand", text: $quantity)
                            .keyboardType(.numberPad)
                        Text("vials").foregroundColor(.secondary)
                    }
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Blend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddFromLibrary) {
                AddFromLibrarySheet(peptides: viewModel.inventoryPeptides) { comp in
                    components.append(comp)
                }
            }
            .sheet(isPresented: $showCreatePeptide) {
                CreateBlendPeptideSheet(viewModel: viewModel) { comp in
                    components.append(comp)
                }
            }
        }
    }

    private func save() {
        guard canSave, let qty = Int(quantity) else { return }
        let blendComponents = components.map { input in
            BlendComponent(
                peptideId: input.peptideId,
                peptideName: input.peptideName,
                mgAmount: input.mg,
                defaultDoseAmountMcg: input.defaultDoseAmountMcg
            )
        }
        let blend = Blend(
            name: name,
            components: blendComponents,
            quantityOnHand: qty,
            purchaseDate: Date(),
            expiryDate: expiryDate
        )
        Task {
            try? await viewModel.addBlend(blend)
            dismiss()
        }
    }
}

// MARK: - AddFromLibrarySheet
private struct AddFromLibrarySheet: View {
    let peptides: [Peptide]
    let onAdd: (BlendComponentInput) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeptide: Peptide?
    @State private var mg = ""

    private var canAdd: Bool { selectedPeptide != nil && Double(mg) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Peptide") {
                    Picker("Select peptide", selection: $selectedPeptide) {
                        Text("Choose…").tag(Optional<Peptide>(nil))
                        ForEach(peptides) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Amount") {
                    HStack {
                        TextField("mg per vial", text: $mg)
                            .keyboardType(.decimalPad)
                        Text("mg").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add from Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let p = selectedPeptide, let mgVal = Double(mg) else { return }
                        let doseAmountMcg: Double
                        switch p.defaultDoseUnit {
                        case .mcg: doseAmountMcg = p.defaultDoseAmount
                        case .mg:  doseAmountMcg = p.defaultDoseAmount * 1000
                        case .iu:  doseAmountMcg = p.defaultDoseAmount
                        }
                        onAdd(BlendComponentInput(
                            peptideId: p.id ?? "",
                            peptideName: p.name,
                            mg: mgVal,
                            defaultDoseAmountMcg: doseAmountMcg
                        ))
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}

// MARK: - CreateBlendPeptideSheet
private struct CreateBlendPeptideSheet: View {
    @ObservedObject var viewModel: StockViewModel
    let onAdd: (BlendComponentInput) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var halfLife = "2.0"
    @State private var doseAmount = ""
    @State private var doseUnit: DoseUnit = .mcg
    @State private var mg = ""
    @State private var isSaving = false

    private var canSave: Bool {
        !name.isEmpty && Double(halfLife) != nil && Double(doseAmount) != nil && Double(mg) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Peptide Info") {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Half-life", text: $halfLife)
                            .keyboardType(.decimalPad)
                        Text("hours").foregroundColor(.secondary)
                    }
                }
                Section("Default Dose") {
                    HStack {
                        TextField("Amount", text: $doseAmount)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 140)
                    }
                }
                Section("Amount in This Blend") {
                    HStack {
                        TextField("mg per vial", text: $mg)
                            .keyboardType(.decimalPad)
                        Text("mg").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Peptide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAndAdd() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func saveAndAdd() {
        guard canSave, let hl = Double(halfLife), let da = Double(doseAmount), let mgVal = Double(mg) else { return }
        isSaving = true
        Task {
            do {
                let peptideId = try await viewModel.addBlendOnlyPeptide(
                    name: name,
                    halfLifeHours: hl,
                    defaultDoseAmount: da,
                    defaultDoseUnit: doseUnit
                )
                let doseAmountMcg: Double
                switch doseUnit {
                case .mcg: doseAmountMcg = da
                case .mg:  doseAmountMcg = da * 1000
                case .iu:  doseAmountMcg = da
                }
                onAdd(BlendComponentInput(
                    peptideId: peptideId,
                    peptideName: name,
                    mg: mgVal,
                    defaultDoseAmountMcg: doseAmountMcg
                ))
                dismiss()
            } catch {
                isSaving = false
            }
        }
    }
}

// MARK: - RestockBlendSheet
struct RestockBlendSheet: View {
    @ObservedObject var viewModel: StockViewModel
    let blend: Blend
    @Environment(\.dismiss) var dismiss
    @State private var additionalQty = "1"

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Stock") {
                    HStack {
                        Text(blend.name).foregroundColor(.secondary)
                        Spacer()
                        TextField("Qty", text: $additionalQty)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("vials").foregroundColor(.secondary)
                    }
                }
                Section {
                    Text("Current stock: \(blend.quantityOnHand) vials")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Restock \(blend.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let qty = Int(additionalQty), qty > 0 else { return }
                        var updated = blend
                        updated.quantityOnHand += qty
                        Task {
                            try? await viewModel.updateBlend(updated)
                            dismiss()
                        }
                    }
                    .disabled(Int(additionalQty) == nil || (Int(additionalQty) ?? 0) <= 0)
                }
            }
        }
    }
}

// MARK: - Add Inventory Type Picker
struct AddInventoryTypePicker: View {
    let onPeptide: () -> Void
    let onBlend: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("What would you like to add?")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 8)

            HStack(spacing: 12) {
                typeCard(
                    icon: "pill.fill",
                    iconColor: .blue,
                    title: "Peptide",
                    subtitle: "A single compound\nyou source separately",
                    action: onPeptide
                )
                typeCard(
                    icon: "flask.fill",
                    iconColor: .purple,
                    title: "Blend",
                    subtitle: "A pre-mixed vial with\nmultiple compounds",
                    action: onBlend
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.08, green: 0.09, blue: 0.14))
        .preferredColorScheme(.dark)
    }

    private func typeCard(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                    .frame(width: 56, height: 56)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(title)
                    .font(.subheadline).bold()
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
