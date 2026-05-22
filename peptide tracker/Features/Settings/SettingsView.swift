import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showClearAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showAppleDeletionSheet = false
    @State private var showEmailUpgrade = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                List {
                    Section {
                        AccountStatusCard(accountStatus: viewModel.accountStatus)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                        
                        if viewModel.accountStatus.isAnonymous {
                            AccountUpgradeCard(
                                viewModel: viewModel,
                                showEmailUpgrade: $showEmailUpgrade
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                        }

                        if let authMessage = viewModel.authMessage {
                            AuthNotice(message: authMessage, systemImage: "checkmark.circle.fill", color: .green)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }

                        if let authError = viewModel.authError {
                            AuthNotice(message: authError, systemImage: "exclamationmark.triangle.fill", color: .orange)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Account")
                    }
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
                        if !viewModel.notificationsEnabled {
                            Button {
                                Task { await viewModel.requestNotificationPermission() }
                            } label: {
                                Label("Enable Dose Reminders", systemImage: "bell.badge")
                            }
                        }
                        Text("Reminder alerts use private wording and do not include compound names, dose amounts, or injection instructions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Label("Clear Tracking Data", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            showDeleteAccountAlert = true
                        } label: {
                            Label(viewModel.isDeletingAccount ? "Deleting Account..." : "Delete Account", systemImage: "person.crop.circle.badge.xmark")
                        }
                        .disabled(viewModel.isDeletingAccount)
                    } header: {
                        Text("Data")
                    } footer: {
                        Text("Account deletion removes your app account and associated tracking data. If you use Sign in with Apple, Apple will ask you to authorize token revocation first.")
                    }
                    Section("Legal") {
                        NavigationLink("Medical Disclaimer") {
                            LegalNoticeView()
                        }
                        Link("Privacy Policy", destination: LegalContent.privacyPolicyURL)
                        Link("Terms of Service", destination: LegalContent.termsOfServiceURL)
                        Link("Support", destination: LegalContent.supportURL)
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
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete Account", role: .destructive) {
                    if viewModel.requiresAppleAuthorizationForDeletion {
                        showAppleDeletionSheet = true
                    } else {
                        Task { await viewModel.deleteAccount() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your Peptide Tracker account and associated tracking data. This cannot be undone.")
            }
            .sheet(isPresented: $showAppleDeletionSheet) {
                AppleAccountDeletionSheet(viewModel: viewModel)
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}

private struct LegalNoticeView: View {
    var body: some View {
        List {
            Section("Medical Disclaimer") {
                Text(LegalContent.medicalDisclaimer)
            }
            Section("Methodology") {
                Text("Half-life charts estimate remaining amount from user-entered dose logs with exponential decay. They are for personal record keeping only and should not be used to diagnose, treat, or change a medical plan.")
            }
            Section("Links") {
                Link("Privacy Policy", destination: LegalContent.privacyPolicyURL)
                Link("Terms of Service", destination: LegalContent.termsOfServiceURL)
                Link("Support", destination: LegalContent.supportURL)
            }
        }
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppleAccountDeletionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Authorize account deletion")
                    .font(.title2.weight(.bold))

                Text("Apple requires a fresh authorization code before Peptide Tracker can revoke your Sign in with Apple token and delete your account.")
                    .font(.body)
                    .foregroundColor(.secondary)

                SignInWithAppleButton(.continue) { request in
                    viewModel.prepareAppleAccountDeletion(request)
                } onCompletion: { result in
                    Task {
                        await viewModel.handleAppleAccountDeletion(result)
                        if viewModel.authError == nil {
                            dismiss()
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                if let authError = viewModel.authError {
                    Text(authError)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct AccountStatusCard: View {
    let accountStatus: AccountStatus

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: accountStatus.isAnonymous ? "person.crop.circle" : "checkmark.icloud.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(accountStatus.title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(accountStatus.detail)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(accountStatus.badge)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(iconColor.opacity(0.14))
                .foregroundColor(iconColor)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var iconColor: Color {
        accountStatus.isAnonymous ? .orange : .green
    }
}

private struct AccountUpgradeCard: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var showEmailUpgrade: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save your account")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                Text("Add a sign-in method to keep your protocol history backed up and available when you switch devices.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                UpgradeBenefitRow(systemImage: "icloud.and.arrow.up", title: "Backup", detail: "Keep your logs tied to your account")
                UpgradeBenefitRow(systemImage: "iphone.and.arrow.forward", title: "Restore", detail: "Pick up your history on a new device")
                UpgradeBenefitRow(systemImage: "lock.shield", title: "Secure", detail: "Your anonymous data upgrades in place")
            }

            VStack(spacing: 9) {
                SignInWithAppleButton(.continue) { request in
                    viewModel.prepareAppleSignIn(request)
                } onCompletion: { result in
                    Task { await viewModel.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                UpgradeActionButton(
                    title: viewModel.isSigningInWithGoogle ? "Connecting Google..." : "Continue with Google",
                    systemImage: "globe",
                    foregroundColor: .black,
                    backgroundColor: .white
                ) {
                    viewModel.signInWithGoogle()
                }
                .disabled(viewModel.isSigningInWithGoogle)

                UpgradeActionButton(
                    title: showEmailUpgrade ? "Hide Email Setup" : "Continue with Email",
                    systemImage: showEmailUpgrade ? "chevron.up" : "envelope",
                    foregroundColor: .white,
                    backgroundColor: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEmailUpgrade.toggle()
                    }
                }
            }

            if showEmailUpgrade {
                EmailUpgradeForm(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(red: 0.10, green: 0.12, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct UpgradeBenefitRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.58))
            }

            Spacer()
        }
    }
}

private struct UpgradeActionButton: View {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct EmailUpgradeForm: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Email address", text: $viewModel.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            UpgradeActionButton(
                title: viewModel.isSendingEmailLink ? "Sending Link..." : "Send Magic Link",
                systemImage: "paperplane.fill",
                foregroundColor: .white,
                backgroundColor: .blue.opacity(0.82)
            ) {
                Task { await viewModel.sendEmailSignInLink() }
            }
            .disabled(viewModel.isSendingEmailLink)

            TextField("Paste sign-in link", text: $viewModel.emailSignInLink, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            UpgradeActionButton(
                title: viewModel.isCompletingEmailSignIn ? "Verifying..." : "Complete Email Sign-In",
                systemImage: "link",
                foregroundColor: .white,
                backgroundColor: Color(red: 0.18, green: 0.22, blue: 0.32)
            ) {
                Task { await viewModel.completeEmailSignIn() }
            }
            .disabled(viewModel.isCompletingEmailSignIn)
        }
        .padding(14)
        .background(Color.black.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AuthNotice: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
