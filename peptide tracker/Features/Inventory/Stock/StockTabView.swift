import SwiftUI

struct StockTabView: View {
    @ObservedObject var viewModel: StockViewModel
    let userId: String
    @State private var showRestockAlert = false
    @State private var restockPeptideName = ""

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            if viewModel.stockItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No stock").font(.title2).bold().foregroundColor(.white)
                    Text("Tap + to add vials to your inventory.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.stockItems) { stock in
                            if let peptide = viewModel.peptide(for: stock) {
                                Group {
                                    if stock.quantityOnHand > 0 {
                                        NavigationLink {
                                            ReconstitutionView(
                                                userId: userId,
                                                viewModel: ReconstitutionViewModel(
                                                    primaryStock: stock,
                                                    primaryPeptide: peptide,
                                                    allPeptides: viewModel.peptides,
                                                    allStocks: viewModel.stockItems,
                                                    vialRepo: VialRepository(userId: userId),
                                                    stockRepo: StockRepository(userId: userId)
                                                )
                                            )
                                        } label: {
                                            StockRowView(stock: stock, peptideName: peptide.name)
                                        }
                                    } else {
                                        Button {
                                            restockPeptideName = peptide.name
                                            showRestockAlert = true
                                        } label: {
                                            StockRowView(stock: stock, peptideName: peptide.name)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { try? await viewModel.delete(stock) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Out of Stock", isPresented: $showRestockAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(restockPeptideName) has no vials left. Restock it from the Peptides tab before reconstituting.")
        }
    }
}

struct AddStockView: View {
    @ObservedObject var viewModel: StockViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeptide: Peptide?
    @State private var mgPerVial = ""
    @State private var quantity = "1"
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    var preselectedPeptide: Peptide? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Peptide") {
                    Picker("Peptide", selection: $selectedPeptide) {
                        Text("Select…").tag(Optional<Peptide>(nil))
                        ForEach(viewModel.peptides) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                }
                Section("Vial Details") {
                    TextField("mg per vial (e.g. 5)", text: $mgPerVial)
                        .keyboardType(.decimalPad)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let peptide = selectedPeptide,
                              let peptideId = peptide.id,
                              let mg = Double(mgPerVial),
                              let qty = Int(quantity) else { return }
                        let stock = PeptideStock(
                            peptideId: peptideId,
                            mgPerVial: mg,
                            quantityOnHand: qty,
                            purchaseDate: Date(),
                            expiryDate: expiryDate
                        )
                        Task {
                            try? await viewModel.addStock(stock)
                            dismiss()
                        }
                    }
                    .disabled(selectedPeptide == nil || mgPerVial.isEmpty)
                }
            }
        }
        .onAppear {
            if let p = preselectedPeptide { selectedPeptide = p }
        }
    }
}
