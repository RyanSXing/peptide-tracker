import SwiftUI

struct ContentView: View {
    let userId: String
    @State private var showInjectSheet = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                viewModel: DashboardViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    vialRepo: VialRepository(userId: userId),
                    stockRepo: StockRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId)
                )
            )
            .tabItem { Label("Dashboard", systemImage: "house.fill") }
            .tag(0)

            InventoryView(userId: userId)
                .tabItem { Label("Inventory", systemImage: "archivebox.fill") }
                .tag(1)

            Color.clear
                .tabItem { Label("Inject", systemImage: "plus.circle.fill") }
                .tag(2)

            HistoryView(
                viewModel: HistoryViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    logRepo: LogRepository(userId: userId)
                )
            )
            .tabItem { Label("History", systemImage: "clock.fill") }
            .tag(3)

            SettingsView(
                viewModel: SettingsViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId),
                    userRepo: UserRepository(userId: userId)
                )
            )
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(4)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showInjectSheet = true
                selectedTab = 0
            }
        }
        .sheet(isPresented: $showInjectSheet) {
            InjectSheetView(
                viewModel: InjectViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    vialRepo: VialRepository(userId: userId),
                    logRepo: LogRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId)
                ),
                isPresented: $showInjectSheet
            )
        }
    }
}

#Preview {
    ContentView(userId: "preview-user")
}
