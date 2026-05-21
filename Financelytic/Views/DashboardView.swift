import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var incomeProfiles: [IncomeProfile]
    @Query private var mortgages: [Mortgage]
    @Query private var loans: [PersonalLoan]
    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var billToMarkPaid: Transaction? = nil

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

    private var totalMonthlyExpenses: Double { txExpense }
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
    // MARK: - Chart data

    private struct SpendingSlice: Identifiable {
        var id: String { label }
        let label: String
        let amount: Double
        let color: Color
        let icon: String
    }

    private func catColor(_ cat: ExpenseCategory) -> Color {
        switch cat {
        case .housing:        return .blue
        case .utilities:      return .yellow
        case .food:           return .green
        case .transportation: return .orange
        case .insurance:      return .purple
        case .entertainment:  return .pink
        case .subscription:   return .teal
        case .debt:           return Color(red: 0.9, green: 0.25, blue: 0.3)
        case .healthcare:     return .mint
        case .other:          return .gray
        }
    }

    private var spendingSlices: [SpendingSlice] {
        var items: [SpendingSlice] = []
        for cat in ExpenseCategory.allCases {
            let t = txCategoryTotal(cat)
            if t > 0 { items.append(.init(label: cat.rawValue, amount: t, color: catColor(cat), icon: cat.icon)) }
        }
        if mortgageMonthly > 0 {
            items.append(.init(label: "Mortgage", amount: mortgageMonthly, color: .indigo, icon: "building.2.fill"))
        }
        if loanMonthlyTotal > 0 {
            items.append(.init(label: "Loans", amount: loanMonthlyTotal, color: .orange, icon: "person.2.fill"))
        }
        return items.sorted { $0.amount > $1.amount }
    }

    private var chartSlices: [SpendingSlice] {
        var all = spendingSlices
        if monthlyIncome > 0 && netRemaining > 0 {
            all.append(.init(label: "Remaining", amount: netRemaining,
                             color: Color.primary.opacity(0.09), icon: "checkmark"))
        }
        return all
    }

    // Transaction-derived snapshot tiles
    private var loanPaymentsThisMonth: Double {
        currentMonthTransactions
            .filter { $0.type == .expense && $0.category == .debt }
            .reduce(0) { $0 + $1.amount }
    }
    private var expenseCountThisMonth: Int {
        currentMonthTransactions.filter { $0.type == .expense }.count
    }
    private var housingSpendThisMonth: Double {
        currentMonthTransactions
            .filter { $0.type == .expense && $0.category == .housing }
            .reduce(0) { $0 + $1.amount }
    }

    // Bills (scheduled but not yet paid)
    private var allUpcomingBills: [Transaction] {
        transactions.filter { !$0.isPaid && $0.dueDate != nil }
    }
    private var overdueBills: [Transaction] {
        allUpcomingBills.filter { $0.isOverdue }
    }
    private var upcomingBills: [Transaction] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let in30 = cal.date(byAdding: .day, value: 30, to: today) ?? today
        return allUpcomingBills
            .filter { tx in
                guard let due = tx.dueDate else { return false }
                return due >= today && due <= in30
            }
    }
    /// Combined list shown in the Dashboard's Upcoming & Overdue section.
    private var billsToShow: [Transaction] {
        (overdueBills + upcomingBills).sorted {
            ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast)
        }
    }
    private var overdueBillsCount: Int { overdueBills.count }
    private var incomeSubtitle: String {
        let sources = incomeProfiles.count
        let recurringPart = sources > 0 ? "\(sources) source\(sources == 1 ? "" : "s")" : ""
        let txPart = txIncome > 0 ? "\(txIncome.currencyFormatted) from transactions" : ""
        if !recurringPart.isEmpty && !txPart.isEmpty { return "\(recurringPart) · \(txPart)" }
        if !recurringPart.isEmpty { return recurringPart }
        if !txPart.isEmpty { return txPart }
        return "No income yet"
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
                    if incomeProfiles.isEmpty && txIncome == 0 {
                        noIncomeCard
                    } else {
                        incomeCard
                        balanceRow
                        if !spendingSlices.isEmpty { spendingChartCard }
                        if debtToIncomeRatio > 0 { dtiCard }
                    }
                    if !billsToShow.isEmpty { upcomingBillsSection }
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
            .sheet(item: $billToMarkPaid) { bill in
                MarkBillPaidView(bill: bill)
            }
        }
    }

    // MARK: - Cards

    private var noIncomeCard: some View {
        HStack(spacing: 18) {
            LogoMark(size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Financelytic")
                    .font(.headline).foregroundStyle(.primary)
                Text("Open Settings to add your income and unlock your full financial overview.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .glassCard()
    }

    private var incomeCard: some View {
        HStack(spacing: 18) {
            LogoMark(size: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text("Total Monthly Income")
                    .font(.caption).foregroundStyle(.secondary)
                Text(monthlyIncome.currencyFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(incomeSubtitle)
                    .font(.caption2).foregroundStyle(.secondary)
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
                    .minimumScaleFactor(0.6).lineLimit(1)
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
                    .minimumScaleFactor(0.6).lineLimit(1)
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

    // MARK: - Upcoming & Overdue Bills

    private var upcomingBillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming & Overdue").font(.headline)
                Spacer()
                Text("\(billsToShow.count)")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Capsule())
            }
            ForEach(Array(billsToShow.prefix(5))) { bill in
                billRow(bill)
            }
            if billsToShow.count > 5 {
                Text("+ \(billsToShow.count - 5) more")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .glassCard()
    }

    private func billRow(_ bill: Transaction) -> some View {
        let overdue = bill.isOverdue
        let color: Color = overdue ? Color(red: 0.9, green: 0.2, blue: 0.3) : .appGold
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: bill.category.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name.isEmpty ? bill.category.rawValue : bill.name)
                    .font(.subheadline.weight(.medium))
                if let due = bill.dueDate {
                    if overdue {
                        Text("Overdue · \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(color)
                    } else {
                        Text(due, style: .date)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(bill.amount.currencyFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(overdue ? color : .primary)
            Button {
                billToMarkPaid = bill
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appGreen)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Spending Chart

    private var spendingChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Spending Breakdown").font(.headline)
                Spacer()
                Text(totalObligations.currencyFormatted)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }

            // Donut chart with center label
            ZStack {
                Chart(chartSlices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.amount),
                        innerRadius: .ratio(0.618),
                        outerRadius: .inset(6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.color)
                }
                .chartLegend(.hidden)
                .frame(height: 190)

                VStack(spacing: 3) {
                    Text(netRemaining >= 0 ? netRemaining.currencyFormatted : "Over")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(netRemaining >= 0 ? Color.appGreen : Color(red: 0.9, green: 0.25, blue: 0.3))
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .frame(maxWidth: 88)
                    Text("remaining")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Legend grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(spendingSlices) { slice in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(slice.color)
                            .frame(width: 9, height: 9)
                        Text(slice.label)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(slice.amount.currencyFormatted)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard()
    }

    private var snapshotGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatTile(title: "Active Loans",
                     value: loanPaymentsThisMonth > 0 ? loanPaymentsThisMonth.currencyFormatted : "$0",
                     icon: "person.2.fill",
                     gradient: .warning)
            StatTile(title: "Open Expenses",
                     value: "\(expenseCountThisMonth)",
                     icon: "list.bullet.rectangle.fill",
                     gradient: .accent)
            StatTile(title: "Mortgage Balance",
                     value: housingSpendThisMonth > 0 ? housingSpendThisMonth.currencyFormatted : "$0",
                     icon: "building.2.fill",
                     gradient: LinearGradient(colors: [Color.indigo, Color.blue],
                                              startPoint: .leading, endPoint: .trailing))
            StatTile(title: "Overdue Bills",
                     value: "\(overdueBillsCount)",
                     icon: "exclamationmark.circle.fill",
                     gradient: .danger)
        }
    }
}

// MARK: - Mark Bill Paid

struct MarkBillPaidView: View {
    @Bindable var bill: Transaction
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var paidDate: Date = Date()

    private var billName: String {
        bill.name.isEmpty ? bill.category.rawValue : bill.name
    }

    private var quickDates: [(String, Date)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let original = bill.dueDate ?? today
        return [
            ("Today", today),
            ("Yesterday", yesterday),
            ("Due date", cal.startOfDay(for: original))
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard
                    quickDateCard
                    customDateCard
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .premiumBackground()
            .navigationTitle("Mark Paid")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { markPaid() }
                        .fontWeight(.semibold).tint(.appGreen)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accent.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: bill.category.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient.accent)
            }
            Text(billName).font(.headline)
            Text(bill.amount.currencyFormatted)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            if let due = bill.dueDate {
                Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickDateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When was it paid?")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(quickDates, id: \.0) { label, d in
                    let selected = Calendar.current.isDate(paidDate, inSameDayAs: d)
                    Button { paidDate = d } label: {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? Color.appGreen.opacity(0.18) : Color.primary.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(selected ? Color.appGreen : Color.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(selected ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var customDateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Payment date", selection: $paidDate, displayedComponents: .date)
                .font(.subheadline)
                .tint(.appGreen)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func markPaid() {
        bill.isPaid = true
        bill.date = paidDate
        BillNotificationManager.cancel(for: bill)
        try? modelContext.save()
        dismiss()
    }
}
