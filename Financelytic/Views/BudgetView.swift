import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var expenses: [Expense]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @State private var showingAI = false

    private var monthlyIncome: Double { incomeProfiles.first?.monthlyAmount ?? 0 }

    private func categoryTotal(_ cat: ExpenseCategory) -> Double {
        expenses.filter { $0.category == cat && !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    private var mortgageMonthly: Double { mortgages.first?.monthlyPayment ?? 0 }
    private var loanMonthly: Double {
        loans.filter { !$0.isPaidOff }.reduce(0) { $0 + $1.monthlyEquivalent }
    }
    private var totalObligations: Double {
        ExpenseCategory.allCases.reduce(0) { $0 + categoryTotal($1) } + mortgageMonthly + loanMonthly
    }
    private var netRemaining: Double { monthlyIncome - totalObligations }
    private var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return max(netRemaining, 0) / monthlyIncome * 100
    }
    private var debtToIncome: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (mortgageMonthly + loanMonthly) / monthlyIncome * 100
    }
    private var needsTotal: Double {
        categoryTotal(.housing) + categoryTotal(.utilities) + categoryTotal(.food) +
        categoryTotal(.transportation) + categoryTotal(.insurance) + categoryTotal(.healthcare) + mortgageMonthly
    }
    private var wantsTotal: Double {
        categoryTotal(.entertainment) + categoryTotal(.subscription) + categoryTotal(.other)
    }
    private var debtTotal: Double { categoryTotal(.debt) + loanMonthly }

    private var activeCategories: [(ExpenseCategory, Double)] {
        ExpenseCategory.allCases.map { ($0, categoryTotal($0)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if monthlyIncome == 0 {
                    VStack(spacing: 20) {
                        LogoMark(size: 70)
                        Text("No Income Set").font(.title2.bold())
                        Text("Set your net income from the Dashboard to see your budget overview.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .premiumBackground()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            overviewCard
                            ruleCard
                            if !activeCategories.isEmpty { categoryCard }
                            if mortgageMonthly > 0 || loanMonthly > 0 { debtCard }
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
                        Label("AI", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LinearGradient.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAI) {
                NavigationStack { AIBudgetAssistantView() }
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Cards

    private var overviewCard: some View {
        VStack(spacing: 14) {
            // Metric row
            HStack(spacing: 0) {
                metricBlock("Income", monthlyIncome.currencyFormatted, .appGreen)
                Divider().frame(height: 40).background(.white.opacity(0.1))
                metricBlock("Spending", totalObligations.currencyFormatted,
                            Color(red:0.9,green:0.25,blue:0.3))
                Divider().frame(height: 40).background(.white.opacity(0.1))
                metricBlock("Left Over", netRemaining.currencyFormatted,
                            netRemaining >= 0 ? .appGreen : Color(red:0.9,green:0.25,blue:0.3))
            }
            // Usage bar
            VStack(spacing: 6) {
                AccentProgressBar(
                    value: monthlyIncome > 0 ? totalObligations / monthlyIncome : 0,
                    height: 9,
                    gradient: totalObligations > monthlyIncome ? .danger : .accent
                )
                HStack {
                    Text("\(Int(min(totalObligations / max(monthlyIncome, 1) * 100, 100)))% of income used")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Savings: \(savingsRate.percentFormatted)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(savingsRate >= 20 ? .appGreen : savingsRate >= 10 ? .appGold : Color(red:0.9,green:0.25,blue:0.3))
                }
            }
        }
        .glassCard()
    }

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("50 / 30 / 20 Rule").font(.headline)
                Spacer()
                Text("Framework").font(.caption2).foregroundStyle(.secondary)
            }
            ruleRow("Needs (50%)", needsTotal, 0.50, .accent)
            ruleRow("Wants (30%)", wantsTotal, 0.30,
                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
            ruleRow("Savings & Debt (20%)", debtTotal + max(netRemaining,0), 0.20,
                    LinearGradient(colors: [.appGold, Color(red:0.9,green:0.6,blue:0.1)], startPoint: .leading, endPoint: .trailing))
        }
        .glassCard()
    }

    private func ruleRow(_ label: String, _ actual: Double, _ fraction: Double, _ gradient: LinearGradient) -> some View {
        let target = monthlyIncome * fraction
        let progress = target > 0 ? min(actual / target, 1.5) : 0
        let over = actual > target
        return VStack(spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(actual.currencyFormatted).font(.subheadline.weight(.semibold))
                    .foregroundStyle(over ? Color(red:0.9,green:0.25,blue:0.3) : .primary)
                Text("/ \(target.currencyFormatted)").font(.caption).foregroundStyle(.secondary)
            }
            AccentProgressBar(value: min(progress, 1), gradient: over ? .danger : gradient)
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By Category").font(.headline)
            ForEach(activeCategories, id: \.0) { cat, total in
                let pct = monthlyIncome > 0 ? total / monthlyIncome * 100 : 0
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(LinearGradient.accent.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: cat.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LinearGradient.accent)
                        }
                        Text(cat.rawValue).font(.subheadline)
                        Spacer()
                        Text(total.currencyFormatted).font(.subheadline.weight(.semibold))
                        Text(pct.percentFormatted).font(.caption).foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    AccentProgressBar(value: pct / 50)
                }
            }
        }
        .glassCard()
    }

    private var debtCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Debt Obligations").font(.headline)
                Spacer()
                Text("\(debtToIncome.percentFormatted) DTI")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background((debtToIncome < 36 ? Color.appGreen : Color.appGold).opacity(0.15))
                    .foregroundStyle(debtToIncome < 36 ? Color.appGreen : Color.appGold)
                    .clipShape(Capsule())
            }
            if mortgageMonthly > 0 {
                debtRow("Mortgage", mortgageMonthly, "building.2.fill")
            }
            if loanMonthly > 0 {
                debtRow("Personal Loans /mo", loanMonthly, "person.2.fill")
            }
            Text("Keep total debt below 36% of income").font(.caption2).foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private func debtRow(_ label: String, _ amount: Double, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(LinearGradient.accent).frame(width: 20)
            Text(label).font(.subheadline)
            Spacer()
            Text(amount.currencyFormatted).font(.subheadline.weight(.semibold))
            Text(monthlyIncome > 0 ? (amount / monthlyIncome * 100).percentFormatted : "–")
                .font(.caption).foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
        }
    }

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
                    Text("Create AI Budget Plan").font(.headline).foregroundStyle(.primary)
                    Text("Apple Intelligence builds a personalized plan from your real data.")
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

    private func metricBlock(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
