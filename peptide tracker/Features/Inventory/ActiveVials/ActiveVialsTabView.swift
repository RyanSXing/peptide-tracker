import SwiftUI

struct ActiveVialsTabView: View {
    @StateObject var viewModel: ActiveVialsViewModel

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            if viewModel.vials.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No active vials").font(.title2).bold().foregroundColor(.white)
                    Text("Reconstitute a vial from the Stock tab.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.vials) { vial in
                            NavigationLink {
                                VialDetailView(vial: vial) {
                                    Task { try? await viewModel.delete(vial) }
                                }
                            } label: {
                                VialRowView(vial: vial)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { try? await viewModel.delete(vial) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct VialDetailView: View {
    let vial: ActiveVial
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false

    private var liquidColor: Color {
        if vial.isExpired { return .red }
        if vial.liquidFraction < 0.2 { return .orange }
        return .blue
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Doses bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(vial.dosesRemaining) of \(vial.totalDoses) doses remaining")
                                .font(.subheadline).foregroundColor(liquidColor)
                            Spacer()
                            if vial.isExpired {
                                Text("EXPIRED").font(.caption2).bold().foregroundColor(.red)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15)).cornerRadius(4)
                            }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4).fill(liquidColor)
                                    .frame(width: geo.size.width * CGFloat(vial.liquidFraction), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Per-compound details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Compounds").font(.headline).foregroundColor(.white)
                        ForEach(vial.compounds, id: \.peptideId) { c in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(c.peptideName).foregroundColor(.white)
                                    Spacer()
                                    Text(String(format: "%.0f mcg/dose", c.defaultDoseAmountMcg))
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text(String(format: "%.0f mg · %.0f mcg/mL", c.mgInVial, c.concentrationMcgPerML))
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    // Dates
                    VStack(spacing: 8) {
                        infoRow("Constituted", vial.dateConstituted.formatted(as: .medium))
                        infoRow("Expires", vial.estimatedExpiry.formatted(as: .medium))
                        infoRow("BAC Water", String(format: "%.1f mL", vial.bacWaterML))
                        infoRow("Age", "\(vial.daysSinceConstitution) days")
                    }
                    .padding()
                    .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                    .cornerRadius(12)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Vial", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
            }
        }
        .navigationTitle(vial.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("Delete Vial", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this vial? This cannot be undone.")
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(.white)
        }
        .font(.subheadline)
    }
}
