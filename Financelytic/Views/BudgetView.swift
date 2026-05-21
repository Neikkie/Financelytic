import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @Query private var transactions: [Transaction]
    @State private var showingAI = false
    @AppStorage("showFiftyThirtyTwenty") private var showFiftyThirtyTwenty: Bool = false

    // Current calendar month bounds
    private var monthStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }
    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? Date()
    }
    private var currentMonthTransactions: [Transaction] {
        transactions.filter { $0.date >= monthStart && $0.date < monthEnd }
    }
    private var txIncome: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var txExpense: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private func txCategoryTotal(_ cat: ExpenseCategory) -> Double {
        currentMonthTransactions.filter { $0.type == .expense && $0.category == cat }.reduce(0) { $0 + $1.amount }
    }

    private var recurringIncome: Double { incomeProfiles.reduce(0) { $0 + $1.monthlyAmount } }
    private var monthlyIncome: Double { recurringIncome + txIncome }

    private func categoryTotal(_ cat: ExpenseCategory) -> Double {
        txCategoryTotal(cat)
    }
    private var mortgageMonthly: Double { mortgages.first?.monthlyPayment ?? 0 }
    private var loanMonthly: Double {
        loans.filter { !$0.isPaidOff }.reduce(0) { $0 + $1.monthlyEquivalent }
    }
    private var totalSpending: Double {
        ExpenseCategory.allCases.reduce(0) { $0 + categoryTotal($1) } + mortgageMonthly + loanMonthly
    }
    private var netRemaining: Double { monthlyIncome - totalSpending }
    private var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return max(netRemaining, 0) / monthlyIncome * 100
    }

    // All spending line items sorted by amount
    private var spendingItems: [(name: String, icon: String, amount: Double, gradient: LinearGradient)] {
        var items: [(String, String, Double, LinearGradient)] = []
        for cat in ExpenseCategory.allCases {
            let total = categoryTotal(cat)
            if total > 0 { items.append((cat.rawValue, cat.icon, total, categoryGradient(cat))) }
        }
        if mortgageMonthly > 0 {
            items.append(("Mortgage", "building.2.fill", mortgageMonthly,
                          LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing)))
        }
        if loanMonthly > 0 {
            items.append(("Personal Loans", "person.2.fill", loanMonthly, .warning))
        }
        return items.sorted { $0.2 > $1.2 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if monthlyIncome == 0 {
                    VStack(spacing: 20) {
                        LogoMark(size: 70)
                        Text("No Income Set").font(.title2.bold())
                        Text("Go to the Dashboard and set your net income to unlock your budget overview.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .premiumBackground()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            overviewCard
                            if showFiftyThirtyTwenty { fiftyThirtyTwentyCard }
                            if !spendingItems.isEmpty {
                                spendingCard
                            } else {
                                emptySpendingCard
                            }
                            aiCard
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .premiumBackground()
                }
            }
            .navigationTitle("Budget")
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAI = true } label: {
                        Label("AI Plan", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(.appGreen)
                }
            }
            .sheet(isPresented: $showingAI) {
                NavigationStack { AIBudgetAssistantView() }
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 16) {
            // Big remaining number
            VStack(spacing: 4) {
                Text("Left Over This Month")
                    .font(.caption).foregroundStyle(.secondary)
                Text(netRemaining.currencyFormatted)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(netRemaining >= 0 ? LinearGradient.accent : LinearGradient.danger)
                    .minimumScaleFactor(0.5).lineLimit(1)
                if netRemaining < 0 {
                    Label("Over budget by \(abs(netRemaining).currencyFormatted)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.9, green: 0.25, blue: 0.3))
                } else if savingsRate >= 20 {
                    Label("Great savings rate · \(Int(savingsRate))%", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.appGreen)
                }
            }
            .frame(maxWidth: .infinity)

            // Progress bar: spending out of income
            VStack(spacing: 6) {
                AccentProgressBar(
                    value: monthlyIncome > 0 ? min(totalSpending / monthlyIncome, 1) : 0,
                    height: 10,
                    gradient: totalSpending > monthlyIncome ? .danger : .accent
                )
                HStack {
                    Text("\(Int(min(totalSpending / max(monthlyIncome, 1) * 100, 100)))% of income spent")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(savingsRate))% saved")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(savingsRate >= 20 ? Color.appGreen : savingsRate >= 10 ? Color.appGold : Color.secondary)
                }
            }

            Divider()

            // Income vs Spending
            HStack {
                VStack(spacing: 3) {
                    Text(monthlyIncome.currencyFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appGreen)
                    Text("Monthly Income")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32)

                VStack(spacing: 3) {
                    Text(totalSpending.currencyFormatted)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(totalSpending > monthlyIncome
                            ? Color(red: 0.9, green: 0.25, blue: 0.3) : Color.primary)
                    Text("Total Spending")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard()
        .accentGlow(color: netRemaining >= 0 ? .appGreen : Color(red: 0.9, green: 0.25, blue: 0.3), radius: 18)
    }

    // MARK: - 50/30/20 Rule Card (opt-in)

    private var needsTotal: Double {
        categoryTotal(.housing) + categoryTotal(.utilities) + categoryTotal(.food) +
        categoryTotal(.transportation) + categoryTotal(.insurance) + categoryTotal(.healthcare) +
        mortgageMonthly
    }
    private var wantsTotal: Double {
        categoryTotal(.entertainment) + categoryTotal(.subscription) + categoryTotal(.other)
    }
    private var savingsAndDebtTotal: Double {
        categoryTotal(.debt) + loanMonthly + max(netRemaining, 0)
    }

    private var fiftyThirtyTwentyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("50 / 30 / 20 Rule").font(.headline)
                Text("Ideal monthly budget breakdown").font(.caption2).foregroundStyle(.secondary)
            }
            ruleRow("Needs", "50% · Housing, food, essentials", needsTotal, 0.50,
                    LinearGradient(colors: [.appTeal, .blue], startPoint: .leading, endPoint: .trailing))
            Divider()
            ruleRow("Wants", "30% · Entertainment, lifestyle", wantsTotal, 0.30,
                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
            Divider()
            ruleRow("Savings & Debt", "20% · Debt payoff & saving", savingsAndDebtTotal, 0.20,
                    LinearGradient(colors: [.appGold, Color(red: 0.9, green: 0.6, blue: 0.1)],
                                   startPoint: .leading, endPoint: .trailing))
        }
        .glassCard()
    }

    private func ruleRow(_ title: String, _ subtitle: String, _ actual: Double, _ fraction: Double, _ gradient: LinearGradient) -> some View {
        let target = monthlyIncome * fraction
        let over = actual > target && target > 0
        let progress = target > 0 ? min(actual / target, 1.5) : 0
        return VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(actual.currencyFormatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(over ? Color(red: 0.9, green: 0.25, blue: 0.3) : .primary)
                    Text("of \(target.currencyFormatted)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(over ? "Over" : "OK")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(over
                        ? Color(red: 0.9, green: 0.25, blue: 0.3).opacity(0.15)
                        : Color.appGreen.opacity(0.15))
                    .foregroundStyle(over ? Color(red: 0.9, green: 0.25, blue: 0.3) : Color.appGreen)
                    .clipShape(Capsule())
            }
            AccentProgressBar(value: min(progress, 1), gradient: over ? .danger : gradient)
        }
    }

    // MARK: - Spending Breakdown Card

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Where Your Money Goes")
                    .font(.headline)
                Spacer()
                Text(totalSpending.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(spendingItems.enumerated()), id: \.offset) { _, item in
                let pct = monthlyIncome > 0 ? item.amount / monthlyIncome : 0
                VStack(spacing: 5) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.gradient.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.gradient)
                        }
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text(item.amount.currencyFormatted)
                            .font(.subheadline.weight(.semibold))
                        Text("\(Int(pct * 100))%")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                    AccentProgressBar(value: min(pct / 0.3, 1), height: 3, gradient: item.gradient)
                        .padding(.leading, 44)
                }
            }
        }
        .glassCard()
    }

    private var emptySpendingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32)).foregroundStyle(.tertiary)
            Text("No Spending Yet")
                .font(.subheadline.weight(.medium))
            Text("Add expenses, a mortgage, or loans to see your breakdown here.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }

    // MARK: - AI Card

    private var aiCard: some View {
        Button { showingAI = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple.opacity(0.3), .appTeal.opacity(0.2)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Get an AI Budget Plan").font(.headline).foregroundStyle(.primary)
                    Text("Apple Intelligence analyzes your data and gives personalized tips.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(colors: [.purple.opacity(0.4), .appTeal.opacity(0.3)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Helpers

    private func categoryGradient(_ cat: ExpenseCategory) -> LinearGradient {
        switch cat {
        case .housing:        return LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing)
        case .utilities:      return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        case .food:           return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case .transportation: return LinearGradient(colors: [.orange, Color(red: 0.8, green: 0.4, blue: 0.1)], startPoint: .leading, endPoint: .trailing)
        case .insurance:      return LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
        case .entertainment:  return LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
        case .subscription:   return LinearGradient(colors: [.appTeal, .cyan], startPoint: .leading, endPoint: .trailing)
        case .debt:           return LinearGradient(colors: [Color(red: 0.9, green: 0.25, blue: 0.3), .orange], startPoint: .leading, endPoint: .trailing)
        case .healthcare:     return LinearGradient(colors: [.mint, .teal], startPoint: .leading, endPoint: .trailing)
        case .other:          return LinearGradient(colors: [.gray, Color(white: 0.55)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
