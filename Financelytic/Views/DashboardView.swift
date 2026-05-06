import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var expenses: [Expense]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @State private var showingSettings = false
    @State private var showingIncomeSetup = false

    private var income: IncomeProfile? { incomeProfiles.first }
    private var monthlyIncome: Double { income?.monthlyAmount ?? 0 }

    private var totalMonthlyExpenses: Double {
        expenses.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    private var mortgageMonthly: Double { mortgages.first?.monthlyPayment ?? 0 }
    private var loanMonthlyTotal: Double {
        loans.filter { !$0.isPaidOff }.reduce(0) { $0 + $1.monthlyEquivalent }
    }
    private var totalObligations: Double { totalMonthlyExpenses + mortgageMonthly + loanMonthlyTotal }
    private var netRemaining: Double { monthlyIncome - totalObligations }
    private var debtToIncomeRatio: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (mortgageMonthly + loanMonthlyTotal) / monthlyIncome * 100
    }
    private var upcomingExpenses: [Expense] {
        expenses.filter { $0.isDueSoon || $0.isOverdue }.sorted { $0.dueDate < $1.dueDate }
    }
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if income == nil {
                        noIncomeCard
                    } else {
                        incomeCard
                        balanceRow
                        if debtToIncomeRatio > 0 { dtiCard }
                    }
                    if !upcomingExpenses.isEmpty { upcomingSection }
                    snapshotGrid
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .premiumBackground()
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 34, height: 34)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingIncomeSetup) { IncomeSetupView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    // MARK: - Cards

    private var noIncomeCard: some View {
        Button { showingIncomeSetup = true } label: {
            HStack(spacing: 18) {
                LogoMark(size: 56)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Financelytic")
                        .font(.headline).foregroundStyle(.primary)
                    Text("Set your net income to unlock your full financial overview.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .glassCard()
        }
    }

    private var incomeCard: some View {
        HStack(spacing: 18) {
            LogoMark(size: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text("Monthly Net Income")
                    .font(.caption).foregroundStyle(.secondary)
                Text(monthlyIncome.currencyFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                if let income {
                    Text("\(income.amount.currencyFormatted) \(income.frequency.perPeriodLabel)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .glassCard(tint: 0.04)
        .accentGlow(color: .appGreen, radius: 18)
    }

    private var balanceRow: some View {
        HStack(spacing: 14) {
            // Expenses
            VStack(alignment: .leading, spacing: 6) {
                Label("Expenses", systemImage: "arrow.up.circle.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(totalObligations.currencyFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.danger)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 16, padding: 14)

            // Remaining
            VStack(alignment: .leading, spacing: 6) {
                Label("Remaining", systemImage: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(netRemaining.currencyFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(netRemaining >= 0 ? LinearGradient.accent : LinearGradient.danger)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 16, padding: 14)
        }
    }

    private var dtiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Debt-to-Income", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(dtiLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(dtiColor.opacity(0.18))
                    .foregroundStyle(dtiColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(dtiColor.opacity(0.3), lineWidth: 1))
            }
            Text(debtToIncomeRatio.percentFormatted)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(dtiColor)
            AccentProgressBar(value: debtToIncomeRatio / 100,
                              gradient: debtToIncomeRatio < 36 ? .accent : LinearGradient.warning)
            Text("Recommended: below 36% of income")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var dtiColor: Color {
        switch debtToIncomeRatio {
        case ..<36: return .appGreen
        case 36..<43: return .appGold
        default: return Color(red: 0.9, green: 0.25, blue: 0.3)
        }
    }
    private var dtiLabel: String {
        switch debtToIncomeRatio {
        case ..<36: return "Healthy"
        case 36..<43: return "Moderate"
        default: return "High Risk"
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming & Overdue").font(.headline)
                Spacer()
                Text("\(upcomingExpenses.count)").font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            ForEach(Array(upcomingExpenses.prefix(5))) { expense in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((expense.isOverdue ? Color(red:0.9,green:0.2,blue:0.3) : .appGold).opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: expense.category.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(expense.isOverdue ? Color(red:0.9,green:0.2,blue:0.3) : .appGold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.name).font(.subheadline.weight(.medium))
                        if expense.isOverdue {
                            Text("Overdue · \(expense.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(Color(red:0.9,green:0.2,blue:0.3))
                        } else {
                            Text(expense.dueDate, style: .date)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(expense.amount.currencyFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(expense.isOverdue ? Color(red:0.9,green:0.2,blue:0.3) : .primary)
                }
            }
        }
        .glassCard()
    }

    private var snapshotGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatTile(title: "Active Loans",
                     value: "\(loans.filter { !$0.isPaidOff }.count)",
                     icon: "person.2.fill",
                     gradient: .warning)
            StatTile(title: "Open Expenses",
                     value: "\(expenses.filter { !$0.isPaid }.count)",
                     icon: "list.bullet.rectangle.fill",
                     gradient: .accent)
            StatTile(title: "Mortgage Balance",
                     value: mortgages.isEmpty ? "None" : (mortgages.first?.currentBalance.currencyFormatted ?? "–"),
                     icon: "building.2.fill",
                     gradient: LinearGradient(colors: [Color.indigo, Color.blue],
                                              startPoint: .leading, endPoint: .trailing))
            StatTile(title: "Overdue Bills",
                     value: "\(expenses.filter { $0.isOverdue }.count)",
                     icon: "exclamationmark.circle.fill",
                     gradient: .danger)
        }
    }
}
