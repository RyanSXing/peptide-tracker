import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showClearAlert = false

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
                    Section("Data") {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
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
            .alert("Clear All Data", isPresented: $showClearAlert) {
                Button("Delete Everything", role: .destructive) {
                    Task { try? await viewModel.clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all peptides, vials, injection logs, and schedules. This cannot be undone.")
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
