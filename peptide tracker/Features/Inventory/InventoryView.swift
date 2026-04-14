import SwiftUI

struct InventoryView: View {
    let userId: String

    var body: some View {
        NavigationStack {
            TabView {
                StockTabView(
                    viewModel: StockViewModel(
                        stockRepo: StockRepository(userId: userId),
                        peptideRepo: PeptideRepository(userId: userId)
                    ),
                    userId: userId
                )
                .tabItem { Label("Stock", systemImage: "shippingbox.fill") }

                ActiveVialsTabView(
                    viewModel: ActiveVialsViewModel(
                        vialRepo: VialRepository(userId: userId),
                        peptideRepo: PeptideRepository(userId: userId)
                    )
                )
                .tabItem { Label("Active Vials", systemImage: "testtube.2") }
            }
            .navigationTitle("Inventory")
        }
    }
}
