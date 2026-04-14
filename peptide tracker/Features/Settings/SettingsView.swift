import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                List {
                    Section("Peptides & Schedules") {
                        NavigationLink("Manage Peptides") {
                            PeptideManagementView(viewModel: viewModel)
                        }
                    }
                    Section("Notifications") {
                        HStack {
                            Text("Push Notifications")
                            Spacer()
                            Text(viewModel.notificationsEnabled ? "Enabled" : "Disabled")
                                .foregroundColor(viewModel.notificationsEnabled ? .green : .orange)
                                .font(.caption)
                        }
                    }
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
