import SwiftUI
import SwiftData
import SafariServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @Query private var transactions: [Transaction]

    @AppStorage("appearancePreference") private var appearancePreference: String = "system"
    @AppStorage("showFiftyThirtyTwenty") private var showFiftyThirtyTwenty: Bool = false

    @State private var showingIncomeSetup = false
    @State private var showingResetConfirm = false
    @State private var presentedLink: WebLink? = nil

    // Update this if your live website is hosted at a different URL.
    private let websiteBaseURL = "https://neikkie.github.io/Financelytic"

    private var webLinks: [WebLink] {
        [
            WebLink(id: "home",    title: "Home",              icon: "house.fill",           path: ""),
            WebLink(id: "usage",   title: "How to Use",        icon: "book.fill",            path: "/usage"),
            WebLink(id: "privacy", title: "Privacy Policy",    icon: "hand.raised.fill",     path: "/privacy"),
            WebLink(id: "terms",   title: "Terms & Conditions", icon: "doc.text.fill",       path: "/terms")
        ]
    }

    private var totalMonthlyIncome: Double { incomeProfiles.reduce(0) { $0 + $1.monthlyAmount } }

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

                    // Appearance
                    sectionCard("Appearance") {
                        HStack(spacing: 0) {
                            ForEach(["system", "light", "dark"], id: \.self) { mode in
                                Button {
                                    appearancePreference = mode
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode == "system" ? "circle.lefthalf.filled" : mode == "light" ? "sun.max.fill" : "moon.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(appearancePreference == mode ? Color.appGreen : Color.primary)
                                        Text(mode.capitalized)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(appearancePreference == mode ? Color.appGreen : Color.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(appearancePreference == mode ? Color.appGreen.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(appearancePreference == mode ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Income
                    sectionCard("Income") {
                        Button { showingIncomeSetup = true } label: {
                            HStack(spacing: 14) {
                                iconCell("dollarsign.circle.fill", gradient: .accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Income Sources").foregroundStyle(.primary)
                                    if incomeProfiles.isEmpty {
                                        Text("Not set").font(.caption).foregroundStyle(Color.appGold)
                                    } else {
                                        Text("\(incomeProfiles.count) source\(incomeProfiles.count == 1 ? "" : "s") · \(totalMonthlyIncome.currencyFormatted)/mo")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Budget preferences
                    sectionCard("Budget") {
                        Toggle(isOn: $showFiftyThirtyTwenty) {
                            HStack(spacing: 14) {
                                iconCell("chart.pie.fill", gradient: .accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("50 / 30 / 20 Breakdown").foregroundStyle(.primary)
                                    Text("Show the framework card on the Budget tab")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.appGreen)
                    }

                    // Long-term debt management
                    sectionCard("Mortgages & Loans") {
                        VStack(spacing: 12) {
                            NavigationLink {
                                MortgageView()
                            } label: {
                                HStack(spacing: 14) {
                                    iconCell("building.2.fill",
                                             gradient: LinearGradient(colors: [.indigo, .blue],
                                                                      startPoint: .leading, endPoint: .trailing))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Mortgages").foregroundStyle(.primary)
                                        Text("\(mortgages.count) tracked").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                            divider()
                            NavigationLink {
                                PersonalLoansView()
                            } label: {
                                HStack(spacing: 14) {
                                    iconCell("person.2.fill", gradient: .warning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Personal Loans").foregroundStyle(.primary)
                                        Text("\(loans.count) tracked").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    // Data summary
                    sectionCard("Your Data") {
                        VStack(spacing: 12) {
                            dataRow("Transactions", "\(transactions.count)", "list.bullet.rectangle.fill", .accent)
                            divider()
                            dataRow("Income Sources", "\(incomeProfiles.count)", "dollarsign.circle.fill",
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

                    // Resources (in-app web views)
                    sectionCard("Resources") {
                        VStack(spacing: 12) {
                            ForEach(Array(webLinks.enumerated()), id: \.element.id) { idx, link in
                                Button {
                                    presentedLink = link
                                } label: {
                                    HStack(spacing: 14) {
                                        iconCell(link.icon, gradient: .accent)
                                        Text(link.title).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                                if idx < webLinks.count - 1 { divider() }
                            }
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

                    Text("Deleting all data removes income, transactions, mortgage, and loan records permanently.")
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
            .sheet(isPresented: $showingIncomeSetup) {
                IncomeSetupView()
            }
            .sheet(item: $presentedLink) { link in
                if let url = URL(string: websiteBaseURL + link.path) {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
            .confirmationDialog("Reset All Data", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all financial records and cannot be undone.")
            }
        }
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
        Divider()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Mortgage.self)
            try modelContext.delete(model: PersonalLoan.self)
            try modelContext.delete(model: IncomeProfile.self)
            try modelContext.save()
        } catch {
            // batch delete failed — nothing further we can do here
        }
    }
}

// MARK: - Web Link helpers

struct WebLink: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let path: String
}

/// Presents a webpage inside the app using SFSafariViewController.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Color.appGreen)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
