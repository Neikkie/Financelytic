import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Generable Budget Recommendation

@Generable
struct BudgetRecommendation {
    @Guide(description: "A warm, personalized 2-3 sentence budget overview specific to this person's income and spending. If they are overspending, lead with empathy.")
    var summary: String

    @Guide(description: "If monthly spending exceeds monthly income, an urgent 2-3 sentence alert explaining by how much they are overspending and which 1-2 categories to cut first. Empty string if they are not overspending.")
    var overspendingAlert: String

    @Guide(description: "Specific 2-3 sentence strategy for paying off credit card debt or other debt-category spending. Recommend snowball (smallest balance first for momentum) or avalanche (highest interest first to save money). Empty string if they have no debt-category spending.")
    var creditCardStrategy: String

    @Guide(description: "Specific 2-3 sentence guidance on managing Buy Now Pay Later (BNPL) plans such as Affirm, Klarna, Afterpay, Sezzle, Apple Pay Later. Warn about stacking multiple plans and suggest consolidating or paying off early. Empty string if they have no BNPL transactions.")
    var bnplStrategy: String

    @Guide(description: "Recommended percentage of monthly income for housing and rent (0-50)")
    var housingPercent: Int

    @Guide(description: "Recommended percentage of monthly income for savings (5-30)")
    var savingsPercent: Int

    @Guide(description: "Recommended percentage of monthly income for all debt payments (0-40)")
    var debtPercent: Int

    @Guide(description: "Recommended percentage of monthly income for food and groceries (5-20)")
    var foodPercent: Int

    @Guide(description: "Recommended percentage of monthly income for transportation (3-15)")
    var transportPercent: Int

    @Guide(description: "Recommended percentage of monthly income for utilities and services (3-10)")
    var utilitiesPercent: Int

    @Guide(description: "Recommended percentage of monthly income for entertainment and personal spending (0-15)")
    var entertainmentPercent: Int

    @Guide(description: "First specific and actionable financial tip tailored to this person's real numbers")
    var tip1: String

    @Guide(description: "Second specific and actionable financial tip")
    var tip2: String

    @Guide(description: "Third specific and actionable financial tip")
    var tip3: String

    @Guide(description: "Fourth specific and actionable financial tip")
    var tip4: String

    @Guide(description: "Overall financial health rating: exactly one of Excellent, Good, Fair, or Needs Attention")
    var healthRating: String
}

// MARK: - View

struct AIBudgetAssistantView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @Query private var transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss

    @State private var recommendation: BudgetRecommendation? = nil
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var safetyModelMissing = false

    private var model = SystemLanguageModel.default

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
    private var txIncomeThisMonth: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var txExpenseThisMonth: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private func txCategoryTotal(_ cat: ExpenseCategory) -> Double {
        currentMonthTransactions.filter { $0.type == .expense && $0.category == cat }.reduce(0) { $0 + $1.amount }
    }

    private var recurringIncome: Double { incomeProfiles.reduce(0) { $0 + $1.monthlyAmount } }
    private var monthlyIncome: Double { recurringIncome + txIncomeThisMonth }

    private func categoryTotal(_ category: ExpenseCategory) -> Double {
        txCategoryTotal(category)
    }

    private var mortgageMonthly: Double { mortgages.first?.monthlyPayment ?? 0 }
    private var loanMonthly: Double {
        loans.filter { !$0.isPaidOff }.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    var body: some View {
        if safetyModelMissing {
            safetyModelView
        } else {
        switch model.availability {
        case .available:
            mainContent
        case .unavailable(.appleIntelligenceNotEnabled):
            unavailableView(
                icon: "brain.head.profile",
                title: "Apple Intelligence Required",
                message: "Enable Apple Intelligence in Settings › Apple Intelligence & Siri to use this feature."
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .unavailable(.deviceNotEligible):
            unavailableView(
                icon: "iphone.slash",
                title: "Device Not Eligible",
                message: "AI budget planning requires a device that supports Apple Intelligence.",
                action: nil
            )
        case .unavailable(.modelNotReady):
            unavailableView(
                icon: "arrow.down.circle",
                title: "Model Downloading",
                message: "The on-device AI model is still preparing. Please check back in a few minutes.",
                action: nil
            )
        case .unavailable:
            unavailableView(
                icon: "exclamationmark.triangle",
                title: "Temporarily Unavailable",
                message: "AI budget planning is not available right now.",
                action: nil
            )
        }
        } // end safetyModelMissing else
    }

    private var safetyModelView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("AI Model Not Ready")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Apple Intelligence needs a few more minutes to finish setting up. Open Settings → Apple Intelligence & Siri and wait for all models to finish downloading, then come back and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Button("Try Again") {
                safetyModelMissing = false
                errorMessage = nil
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .navigationTitle("AI Budget Planner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                appleIntelligenceBadge

                if monthlyIncome == 0 {
                    noIncomeCard
                } else if isGenerating {
                    loadingCard
                } else if let rec = recommendation {
                    recommendationSection(rec)
                } else {
                    generateCard
                }

                if let error = errorMessage {
                    errorBanner(error)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI Budget Planner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sub Views

    private var appleIntelligenceBadge: some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.intelligence")
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Powered by Apple Intelligence")
                    .font(.subheadline.weight(.semibold))
                Text("All AI processing happens on your device. Your financial data never leaves.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.15), lineWidth: 1))
    }

    private var noIncomeCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "dollarsign.circle").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Income Not Set").font(.headline)
            Text("Go to the Dashboard and set your net income to get a personalized budget plan.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var loadingCard: some View {
        VStack(spacing: 18) {
            ProgressView().scaleEffect(1.4).tint(.purple)
            Text("Analyzing your finances...").font(.headline)
            Text("Apple Intelligence is crafting a personalized budget plan just for you.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var generateCard: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Financial Snapshot").font(.headline)
                snapshotRow("Monthly Income", monthlyIncome.currencyFormatted, .green)
                if txIncomeThisMonth > 0 || txExpenseThisMonth > 0 {
                    Text("Includes \(currentMonthTransactions.count) transactions this month")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                snapshotRow("Housing & Rent", categoryTotal(.housing).currencyFormatted, .blue)
                snapshotRow("Food & Groceries", categoryTotal(.food).currencyFormatted, .mint)
                snapshotRow("Transportation", categoryTotal(.transportation).currencyFormatted, .orange)
                snapshotRow("Utilities", categoryTotal(.utilities).currencyFormatted, .yellow)
                snapshotRow("Entertainment", categoryTotal(.entertainment).currencyFormatted, .pink)
                snapshotRow("Subscriptions", categoryTotal(.subscription).currencyFormatted, .teal)
                if mortgageMonthly > 0 {
                    snapshotRow("Mortgage", mortgageMonthly.currencyFormatted, .indigo)
                }
                if loanMonthly > 0 {
                    snapshotRow("Personal Loans/mo", loanMonthly.currencyFormatted, .orange)
                }
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await generateBudget() }
            } label: {
                Label("Generate My Budget Plan", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func recommendationSection(_ rec: BudgetRecommendation) -> some View {
        // Overspending Alert (only when present)
        if !rec.overspendingAlert.isEmpty {
            alertCard(
                title: "Overspending Alert",
                body: rec.overspendingAlert,
                icon: "exclamationmark.triangle.fill",
                color: Color(red: 0.9, green: 0.25, blue: 0.3)
            )
        }

        // Health Rating
        healthCard(rec.healthRating)

        // Summary
        VStack(alignment: .leading, spacing: 10) {
            Label("Your Budget Plan", systemImage: "sparkles").font(.headline)
            Text(rec.summary).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Credit Card Strategy
        if !rec.creditCardStrategy.isEmpty {
            alertCard(
                title: "Credit Card Payoff Strategy",
                body: rec.creditCardStrategy,
                icon: "creditcard.fill",
                color: .orange
            )
        }

        // BNPL Strategy
        if !rec.bnplStrategy.isEmpty {
            alertCard(
                title: "Buy Now, Pay Later Plan",
                body: rec.bnplStrategy,
                icon: "creditcard.and.123",
                color: .purple
            )
        }

        // Allocation Breakdown
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommended Allocation").font(.headline)
            allocationBar("Housing", rec.housingPercent, .blue)
            allocationBar("Savings", rec.savingsPercent, .green)
            allocationBar("Debt Payments", rec.debtPercent, .orange)
            allocationBar("Food", rec.foodPercent, .mint)
            allocationBar("Transportation", rec.transportPercent, .purple)
            allocationBar("Utilities", rec.utilitiesPercent, .yellow)
            allocationBar("Entertainment", rec.entertainmentPercent, .pink)
            Divider()
            let totalPct = rec.housingPercent + rec.savingsPercent + rec.debtPercent +
                           rec.foodPercent + rec.transportPercent + rec.utilitiesPercent + rec.entertainmentPercent
            HStack {
                Text("Allocated").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(totalPct)%").font(.subheadline.weight(.bold))
                    .foregroundStyle(totalPct <= 100 ? .green : .red)
                Text("· \((monthlyIncome * Double(totalPct) / 100).currencyFormatted)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Action Tips
        VStack(alignment: .leading, spacing: 14) {
            Label("Action Plan", systemImage: "list.bullet.clipboard.fill").font(.headline)
            ForEach(Array([rec.tip1, rec.tip2, rec.tip3, rec.tip4].enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(Circle())
                    Text(tip).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Regenerate
        Button {
            withAnimation { recommendation = nil; errorMessage = nil }
        } label: {
            Label("Generate New Plan", systemImage: "arrow.clockwise")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func alertCard(title: String, body: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func healthCard(_ rating: String) -> some View {
        let (color, icon): (Color, String) = {
            switch rating.lowercased() {
            case let r where r.contains("excellent"): return (.green, "star.fill")
            case let r where r.contains("good"):      return (.blue, "checkmark.circle.fill")
            case let r where r.contains("fair"):      return (.orange, "exclamationmark.circle.fill")
            default:                                   return (.red, "xmark.circle.fill")
            }
        }()
        return HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text("Financial Health").font(.caption).foregroundStyle(.secondary)
                Text(rating).font(.title2.bold()).foregroundStyle(color)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func allocationBar(_ label: String, _ percent: Int, _ color: Color) -> some View {
        let dollarAmount = monthlyIncome * Double(percent) / 100
        return VStack(spacing: 5) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(percent)%").font(.subheadline.weight(.semibold)).foregroundStyle(color)
                Text("· \(dollarAmount.currencyFormatted)").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * Double(percent) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func snapshotRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).font(.subheadline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if message.contains("Settings") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private func unavailableView(icon: String, title: String, message: String, action: (() -> Void)?) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon).font(.system(size: 64)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal)
            if let action {
                Button("Open Settings", action: action).buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .navigationTitle("AI Budget Planner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - AI Generation

    private func generateBudget() async {
        isGenerating = true
        errorMessage = nil

        let housing    = categoryTotal(.housing)
        let utilities  = categoryTotal(.utilities)
        let food       = categoryTotal(.food)
        let transport  = categoryTotal(.transportation)
        let insurance  = categoryTotal(.insurance)
        let entertain  = categoryTotal(.entertainment)
        let subs       = categoryTotal(.subscription)
        let healthcare = categoryTotal(.healthcare)
        let other      = categoryTotal(.other)
        let totalDebt  = mortgageMonthly + loanMonthly
        let dti        = monthlyIncome > 0 ? totalDebt / monthlyIncome * 100 : 0.0
        let totalSpend = housing + utilities + food + transport + insurance +
                         entertain + subs + healthcare + other + totalDebt
        let netLeft    = monthlyIncome - totalSpend

        let txCount = currentMonthTransactions.count
        let txIncomeCount = currentMonthTransactions.filter { $0.type == .income }.count
        let txExpenseCount = currentMonthTransactions.filter { $0.type == .expense }.count

        // Detect BNPL transactions (notes contain "BNPL" prefix from AddBNPLView)
        let bnplTransactions = currentMonthTransactions.filter {
            $0.type == .expense && $0.notes.contains("BNPL")
        }
        let bnplCount = bnplTransactions.count
        let bnplTotal = bnplTransactions.reduce(0) { $0 + $1.amount }
        let bnplProviders = Set(bnplTransactions.compactMap { tx -> String? in
            tx.notes.components(separatedBy: " BNPL").first
        }).sorted().joined(separator: ", ")

        // Debt category spending (credit cards, etc.)
        let debtCategorySpending = currentMonthTransactions
            .filter { $0.type == .expense && $0.category == .debt && !$0.notes.contains("BNPL") }
            .reduce(0) { $0 + $1.amount }

        let isOverspending = totalSpend > monthlyIncome
        let overspendAmount = totalSpend - monthlyIncome

        let prompt = """
        Create a personalized monthly budget plan for this person, based on their actual logged activity for this calendar month.

        STATUS: \(isOverspending ? "OVERSPENDING by \(overspendAmount.currencyFormatted) — this is urgent and needs an empathetic but direct response" : "Net positive cash flow of \(netLeft.currencyFormatted)")

        Income:
        - Recurring income (monthly): \(recurringIncome.currencyFormatted)
        - Income transactions logged this month (\(txIncomeCount) entries): \(txIncomeThisMonth.currencyFormatted)
        - Total monthly net income: \(monthlyIncome.currencyFormatted)

        Spending by Category (combined fixed expenses + this month's transactions):
        - Housing/Rent: \(housing.currencyFormatted)
        - Utilities: \(utilities.currencyFormatted)
        - Food & Groceries: \(food.currencyFormatted)
        - Transportation: \(transport.currencyFormatted)
        - Insurance: \(insurance.currencyFormatted)
        - Entertainment: \(entertain.currencyFormatted)
        - Subscriptions: \(subs.currencyFormatted)
        - Healthcare: \(healthcare.currencyFormatted)
        - Other: \(other.currencyFormatted)
        - Debt Payments (credit cards, etc.): \(debtCategorySpending.currencyFormatted)

        Fixed Debt Obligations:
        - Mortgage Payment: \(mortgageMonthly.currencyFormatted)/month
        - Personal Loan Payments: \(loanMonthly.currencyFormatted)/month
        - Current Debt-to-Income Ratio: \(String(format: "%.1f", dti))%

        Buy Now Pay Later (BNPL) Activity:
        - Active BNPL installments this month: \(bnplCount)
        - Total BNPL outflow this month: \(bnplTotal.currencyFormatted)
        - Providers in use: \(bnplProviders.isEmpty ? "none" : bnplProviders)

        This month at a glance:
        - Total transactions logged: \(txCount) (\(txExpenseCount) expense, \(txIncomeCount) income)
        - Total monthly spending: \(totalSpend.currencyFormatted)
        - Net after expenses: \(netLeft.currencyFormatted)

        Instructions:
        1. If overspending (status above says OVERSPENDING), fill `overspendingAlert` with an empathetic but concrete 2-3 sentence warning naming exactly which 1-2 categories to cut first based on the numbers. If not overspending, set `overspendingAlert` to empty string.
        2. If debt category spending > 0, fill `creditCardStrategy` with a 2-3 sentence payoff plan. Recommend either snowball (smallest balance first for psychological wins) or avalanche (highest interest first to save the most money) — pick whichever fits a beginner better. If no debt spending, set to empty string.
        3. If BNPL count > 0, fill `bnplStrategy` with a 2-3 sentence plan to manage these installments, warn about stacking multiple BNPL plans, and suggest paying off the smallest one first to free up cash flow. If no BNPL, set to empty string.
        4. Provide 4 specific actionable tips that reference their actual logged spending patterns.
        5. Pick a healthRating: Excellent, Good, Fair, or Needs Attention.
        """

        do {
            let session = LanguageModelSession(
                instructions: Instructions(
                    "You are a certified financial planner. Create personalized, realistic budgets. " +
                    "Use the 50/30/20 rule as a guide but adapt to the user's real situation. " +
                    "Be encouraging, specific, and practical. " +
                    "Ensure all percentage recommendations are reasonable and achievable."
                )
            )
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: BudgetRecommendation.self
            )
            await MainActor.run { recommendation = response.content }
        } catch {
            await MainActor.run {
                let nsError = error as NSError
                let isSafetyError = nsError.domain.contains("SensitiveContentAnalysis") ||
                    nsError.domain.contains("SensitiveContentAnalysisML") ||
                    nsError.code == 15 ||
                    nsError.localizedDescription.contains("thoughtContents") ||
                    nsError.localizedDescription.contains("safety") ||
                    (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription.contains("thoughtContents") == true
                if isSafetyError {
                    safetyModelMissing = true
                } else if nsError.localizedDescription.contains("modelNotReady") || nsError.localizedDescription.contains("not ready") {
                    errorMessage = "The AI model isn't ready yet. Please wait a few minutes and try again."
                } else {
                    errorMessage = "Could not generate budget plan. Please try again."
                }
            }
        }

        await MainActor.run { isGenerating = false }
    }
}
