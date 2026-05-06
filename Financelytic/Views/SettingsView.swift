import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var expenses: [Expense]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]

    @State private var showingIncomeSetup = false
    @State private var showingResetConfirm = false

    private var income: IncomeProfile? { incomeProfiles.first }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    HStack(spacing: 16) {
                        LogoMark(size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Financelytic").font(.title3.bold())
                            Text("Version \(appVersion)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .glassCard()
                    .accentGlow(color: .appTeal, radius: 16)

                    // Income
                    sectionCard("Income") {
                        Button { showingIncomeSetup = true } label: {
                            HStack(spacing: 14) {
                                iconCell("dollarsign.circle.fill", gradient: .accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Net Income").foregroundStyle(.primary)
                                    if let income {
                                        Text("\(income.amount.currencyFormatted) \(income.frequency.perPeriodLabel) · \(income.monthlyAmount.currencyFormatted)/mo")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("Not set").font(.caption).foregroundStyle(Color.appGold)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Data summary
                    sectionCard("Your Data") {
                        VStack(spacing: 12) {
                            dataRow("Expenses Tracked", "\(expenses.count)", "list.bullet.rectangle.fill", .accent)
                            divider()
                            dataRow("Paid Expenses", "\(expenses.filter { $0.isPaid }.count)", "checkmark.circle.fill",
                                    LinearGradient(colors: [.appGreen, .appGreen], startPoint: .leading, endPoint: .trailing))
                            divider()
                            dataRow("Mortgages", "\(mortgages.count)", "building.2.fill",
                                    LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing))
                            divider()
                            dataRow("Personal Loans", "\(loans.count)", "person.2.fill", .warning)
                        }
                    }

                    // Features
                    sectionCard("Powered By") {
                        VStack(spacing: 12) {
                            featureRow("Apple Intelligence", "On-device AI budget planning", "apple.intelligence", .purple)
                            divider()
                            featureRow("SwiftData", "Private on-device storage", "lock.shield.fill", .appGreen)
                            divider()
                            featureRow("Privacy First", "Your data never leaves your device", "hand.raised.fill", .appTeal)
                        }
                    }

                    // Support
                    sectionCard("Support") {
                        Link(destination: URL(string: "mailto:support.chaniiapps@gmail.com")!) {
                            HStack(spacing: 14) {
                                iconCell("envelope.fill", gradient: LinearGradient(colors: [.appTeal, .appGreen], startPoint: .leading, endPoint: .trailing))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Contact Support").foregroundStyle(.primary)
                                    Text("support.chaniiapps@gmail.com")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Danger zone
                    sectionCard("Data Management") {
                        Button(role: .destructive) { showingResetConfirm = true } label: {
                            HStack(spacing: 14) {
                                iconCell("trash.fill", gradient: .danger)
                                Text("Reset All Data").foregroundStyle(Color(red:0.9,green:0.2,blue:0.3))
                                Spacer()
                            }
                        }
                    }

                    Text("Deleting all data removes income, expenses, mortgage, and loan records permanently.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 18).padding(.top, 12)
            }
            .premiumBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(LinearGradient.accent)
                }
            }
            .sheet(isPresented: $showingIncomeSetup) {
                IncomeSetupView().preferredColorScheme(.dark)
            }
            .confirmationDialog("Reset All Data", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all financial records and cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .glassCard()
    }

    private func iconCell(_ icon: String, gradient: LinearGradient) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient.opacity(0.2))
                .frame(width: 34, height: 34)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }

    private func dataRow(_ label: String, _ value: String, _ icon: String, _ gradient: LinearGradient) -> some View {
        HStack(spacing: 14) {
            iconCell(icon, gradient: gradient)
            Text(label).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func featureRow(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func divider() -> some View {
        Divider().background(.white.opacity(0.07))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func resetAllData() {
        expenses.forEach   { modelContext.delete($0) }
        mortgages.forEach  { modelContext.delete($0) }
        loans.forEach      { modelContext.delete($0) }
        incomeProfiles.forEach { modelContext.delete($0) }
    }
}
