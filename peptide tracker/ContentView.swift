import SwiftUI

struct ContentView: View {
    let userId: String

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(
                    vialRepo: VialRepository(userId: userId),
                    stockRepo: StockRepository(userId: userId)
                ),
                userId: userId
            )
            .tabItem { Label("Dashboard", systemImage: "house.fill") }

            InventoryView(userId: userId)
                .tabItem { Label("Inventory", systemImage: "archivebox.fill") }

            HistoryView(
                viewModel: HistoryViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    logRepo: LogRepository(userId: userId)
                )
            )
            .tabItem { Label("History", systemImage: "clock.fill") }

            SettingsView(
                viewModel: SettingsViewModel(
                    userId: userId,
                    peptideRepo: PeptideRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId),
                    userRepo: UserRepository(userId: userId)
                )
            )
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView(userId: "preview-user")
}
