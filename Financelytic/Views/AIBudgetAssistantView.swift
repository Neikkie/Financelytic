import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Generable Budget Recommendation

@Generable
struct BudgetRecommendation {
    @Guide(description: "A warm, personalized 2-3 sentence budget overview specific to this person's income and spending")
    var summary: String

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

    @Guide(description: "Three to five specific and actionable financial tips tailored to this person's situation")
    var tips: [String]

    @Guide(description: "Overall financial health rating: exactly one of Excellent, Good, Fair, or Needs Attention")
    var healthRating: String
}

// MARK: - View

struct AIBudgetAssistantView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var expenses: [Expense]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @Environment(\.dismiss) private var dismiss

    @State private var recommendation: BudgetRecommendation? = nil
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    private var model = SystemLanguageModel.default
    private var monthlyIncome: Double { incomeProfiles.first?.monthlyAmount ?? 0 }

    private func categoryTotal(_ category: ExpenseCategory) -> Double {
        expenses.filter { $0.category == category && !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    private var mortgageMonthly: Double { mortgages.first?.monthlyPayment ?? 0 }
    private var loanMonthly: Double {
        loans.filter { !$0.isPaidOff }.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    var body: some View {
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
            ForEach(rec.tips.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(Color.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(Circle())
                    Text(rec.tips[i]).font(.subheadline)
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
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

        let prompt = """
        Create a personalized monthly budget plan for this person.

        Monthly Net Income: \(monthlyIncome.currencyFormatted)

        Current Monthly Spending:
        - Housing/Rent: \(housing.currencyFormatted)
        - Utilities: \(utilities.currencyFormatted)
        - Food & Groceries: \(food.currencyFormatted)
        - Transportation: \(transport.currencyFormatted)
        - Insurance: \(insurance.currencyFormatted)
        - Entertainment: \(entertain.currencyFormatted)
        - Subscriptions: \(subs.currencyFormatted)
        - Healthcare: \(healthcare.currencyFormatted)
        - Other: \(other.currencyFormatted)

        Fixed Debt Obligations:
        - Mortgage Payment: \(mortgageMonthly.currencyFormatted)/month
        - Personal Loan Payments: \(loanMonthly.currencyFormatted)/month
        - Current Debt-to-Income Ratio: \(String(format: "%.1f", dti))%

        Total Monthly Spending: \(totalSpend.currencyFormatted)
        Net After Expenses: \(netLeft.currencyFormatted)

        Provide a realistic budget plan with recommended percentage allocations and 3-5 specific tips.
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
                errorMessage = "Could not generate budget plan. Please try again. (\(error.localizedDescription))"
            }
        }

        await MainActor.run { isGenerating = false }
    }
}
