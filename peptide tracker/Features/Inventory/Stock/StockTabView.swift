import SwiftUI

struct StockTabView: View {
    @StateObject var viewModel: StockViewModel
    let userId: String
    @State private var showAddSheet = false

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
                                NavigationLink {
                                    ReconstitutionView(
                                        viewModel: ReconstitutionViewModel(
                                            stock: stock,
                                            peptide: peptide,
                                            vialRepo: VialRepository(userId: userId),
                                            stockRepo: StockRepository(userId: userId)
                                        )
                                    )
                                } label: {
                                    StockRowView(stock: stock, peptideName: peptide.name)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddStockView(viewModel: viewModel)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .preferredColorScheme(.dark)
    }
}

struct AddStockView: View {
    @ObservedObject var viewModel: StockViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeptide: Peptide?
    @State private var mgPerVial = ""
    @State private var quantity = "1"
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!

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
    }
}

