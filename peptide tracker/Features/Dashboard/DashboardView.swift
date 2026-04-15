import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    let userId: String
    @State private var injectVial: ActiveVial?
    @State private var deleteTarget: ActiveVial?
    @State private var reconstitutionError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView().tint(.blue)
                } else if viewModel.activeVials.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 48)).foregroundColor(.secondary)
                        Text("No Active Vials")
                            .font(.title2).bold().foregroundColor(.white)
                        Text("Open a vial from Inventory to get started.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(viewModel.activeVials.filter(\.isExpired)) { vial in
                            alertBanner(text: "\(vial.displayName): vial may be expired", color: .orange)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        }
                        ForEach(viewModel.activeVials.filter { !$0.isExpired && $0.dosesRemaining <= 3 }) { vial in
                            alertBanner(text: "\(vial.displayName): only \(vial.dosesRemaining) dose(s) left", color: .red)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        }
                        ForEach(viewModel.activeVials) { vial in
                            Button { injectVial = vial } label: {
                                VialCard(vial: vial)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = vial
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task {
                                        do {
                                            try await viewModel.quickReconstitute(vial)
                                        } catch {
                                            reconstitutionError = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    Label("New Vial", systemImage: "cross.vial.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .sheet(item: $injectVial, onDismiss: {
                viewModel.stopListening()
                viewModel.startListening()
            }) { vial in
                InjectSheetView(
                    viewModel: InjectViewModel(
                        vialRepo: VialRepository(userId: userId),
                        logRepo: LogRepository(userId: userId),
                        scheduleRepo: ScheduleRepository(userId: userId),
                        preselectedVial: vial
                    )
                )
            }
            .alert("Delete Vial", isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let vial = deleteTarget {
                        Task { try? await viewModel.deleteVial(vial) }
                    }
                    deleteTarget = nil
                }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("Are you sure you want to delete \(deleteTarget?.displayName ?? "this vial")? This cannot be undone.")
            }
            .alert("Out of Stock", isPresented: Binding(
                get: { reconstitutionError != nil },
                set: { if !$0 { reconstitutionError = nil } }
            )) {
                Button("OK", role: .cancel) { reconstitutionError = nil }
            } message: {
                Text(reconstitutionError ?? "")
            }
        }
        .onAppear { viewModel.startListening() }
    }

    private func alertBanner(text: String, color: Color) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(color)
            Text(text).font(.caption).foregroundColor(.white)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1))
        .cornerRadius(8)
    }
}
