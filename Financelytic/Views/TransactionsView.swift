import SwiftUI
import SwiftData
import Charts

struct TransactionsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    @State private var periodOffset = 0
    @State private var period: Period = .week
    @State private var showingAdd = false
    @State private var prefilledType: TransactionType = .expense
    @State private var editingTx: Transaction? = nil
    @State private var typeFilter: TypeFilter = .all
    @State private var showingDebtChoice = false
    @State private var showingAddMortgage = false
    @State private var showingAddLoan = false
    @State private var showingBNPLProviderChoice = false
    @State private var bnplProvider: String? = nil

    enum Period: String, CaseIterable {
        case day   = "Day"
        case week  = "Week"
        case month = "Month"
    }

    enum TypeFilter: String, CaseIterable {
        case all     = "All"
        case income  = "Income"
        case expense = "Expenses"
    }

    private var calendar: Calendar { Calendar.current }

    private var periodStart: Date {
        switch period {
        case .day:
            let today = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: .day, value: periodOffset, to: today) ?? today
        case .week:
            let base = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return calendar.date(byAdding: .weekOfYear, value: periodOffset, to: base) ?? base
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: Date())
            let base = calendar.date(from: comps) ?? Date()
            return calendar.date(byAdding: .month, value: periodOffset, to: base) ?? base
        }
    }

    private var periodRangeEnd: Date {
        switch period {
        case .day:   return calendar.date(byAdding: .day, value: 1, to: periodStart) ?? periodStart
        case .week:  return calendar.date(byAdding: .day, value: 7, to: periodStart) ?? periodStart
        case .month: return calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
        }
    }

    private var periodTransactions: [Transaction] {
        transactions.filter { $0.date >= periodStart && $0.date < periodRangeEnd }
    }
    private var filteredTransactions: [Transaction] {
        switch typeFilter {
        case .all:     return periodTransactions
        case .income:  return periodTransactions.filter { $0.type == .income }
        case .expense: return periodTransactions.filter { $0.type == .expense }
        }
    }

    private var periodIncome: Double {
        periodTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var periodExpense: Double {
        periodTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    private var periodNet: Double { periodIncome - periodExpense }

    private var groupedByDay: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { calendar.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    private struct DailyBar: Identifiable {
        let date: Date
        let amount: Double
        var id: Date { date }
        var weekday: String {
            let f = DateFormatter()
            f.dateFormat = "EEEEE"
            return f.string(from: date)
        }
    }
    private var dailySpending: [DailyBar] {
        let dayCount: Int
        switch period {
        case .day:   dayCount = 1
        case .week:  dayCount = 7
        case .month:
            dayCount = calendar.range(of: .day, in: .month, for: periodStart)?.count ?? 30
        }
        return (0..<dayCount).compactMap { offset -> DailyBar? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: periodStart) else { return nil }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let total = periodTransactions
                .filter { $0.type == .expense && $0.date >= day && $0.date < nextDay }
                .reduce(0.0) { $0 + $1.amount }
            return DailyBar(date: day, amount: total)
        }
    }

    private var periodTitle: String {
        switch period {
        case .day:
            if periodOffset == 0 { return "Today" }
            if periodOffset == -1 { return "Yesterday" }
            return periodStart.formatted(.dateTime.weekday(.wide))
        case .week:
            switch periodOffset {
            case 0:  return "This Week"
            case -1: return "Last Week"
            case 1:  return "Next Week"
            default:
                if periodOffset < 0 { return "\(abs(periodOffset)) weeks ago" }
                return "\(periodOffset) weeks ahead"
            }
        case .month:
            if periodOffset == 0 { return "This Month" }
            if periodOffset == -1 { return "Last Month" }
            return periodStart.formatted(.dateTime.month(.wide))
        }
    }

    private var periodSubtitle: String {
        switch period {
        case .day:
            return periodStart.formatted(.dateTime.month(.abbreviated).day().year())
        case .week:
            let end = calendar.date(byAdding: .day, value: 6, to: periodStart) ?? periodStart
            return "\(periodStart.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return periodStart.formatted(.dateTime.month(.wide).year())
        }
    }

    private var netLabel: String {
        switch period {
        case .day:   return "Net Today"
        case .week:  return "Net This Week"
        case .month: return "Net This Month"
        }
    }

    private var jumpToCurrentLabel: String {
        switch period {
        case .day:   return "Today"
        case .week:  return "This Week"
        case .month: return "This Month"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    periodSelector
                    periodNavigator
                    heroCard
                    quickActionRow
                    debtActionButton
                    bnplActionButton
                    typeFilterChips
                    if filteredTransactions.isEmpty {
                        emptyState.padding(.top, 20)
                    } else {
                        transactionList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .premiumBackground()
            .navigationTitle("Transactions")
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if periodOffset != 0 {
                        Button { withAnimation { periodOffset = 0 } } label: {
                            Label(jumpToCurrentLabel, systemImage: "calendar")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditTransactionView(prefilledType: prefilledType)
            }
            .sheet(item: $editingTx) { tx in
                AddEditTransactionView(transaction: tx)
            }
            .sheet(isPresented: $showingAddMortgage) { AddMortgageView() }
            .sheet(isPresented: $showingAddLoan) { AddLoanView() }
            .confirmationDialog("Add Mortgage or Loan?",
                                isPresented: $showingDebtChoice,
                                titleVisibility: .visible) {
                Button("Add Mortgage") { showingAddMortgage = true }
                Button("Add Personal Loan") { showingAddLoan = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Long-term debt is tracked separately from regular transactions and contributes to your monthly expenses automatically.")
            }
            .confirmationDialog("Pick a Buy Now, Pay Later provider",
                                isPresented: $showingBNPLProviderChoice,
                                titleVisibility: .visible) {
                ForEach(BNPLProvider.all, id: \.self) { name in
                    Button(name) { bnplProvider = name }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Each installment becomes an expense transaction on its due date.")
            }
            .sheet(item: Binding(
                get: { bnplProvider.map { BNPLChoice(provider: $0) } },
                set: { bnplProvider = $0?.provider }
            )) { choice in
                AddBNPLView(provider: choice.provider)
            }
        }
    }

    private struct BNPLChoice: Identifiable {
        let provider: String
        var id: String { provider }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases, id: \.self) { p in
                let selected = period == p
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        period = p
                        periodOffset = 0
                    }
                } label: {
                    Text(p.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.clear))
                        .foregroundStyle(selected ? Color.black : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Period Navigator

    private var periodNavigator: some View {
        HStack {
            Button { withAnimation { periodOffset -= 1 } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)

            Spacer()

            VStack(spacing: 2) {
                Text(periodTitle).font(.subheadline.weight(.semibold))
                Text(periodSubtitle)
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            Button { withAnimation { periodOffset += 1 } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(netLabel)
                    .font(.caption).foregroundStyle(.secondary)
                Text((periodNet >= 0 ? "+" : "") + periodNet.currencyFormatted)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(periodNet >= 0 ? LinearGradient.accent : LinearGradient.danger)
                    .minimumScaleFactor(0.5).lineLimit(1)
            }

            HStack(spacing: 10) {
                miniStat(label: "Income",
                         value: periodIncome,
                         color: .appGreen,
                         icon: "arrow.down.left")
                miniStat(label: "Spent",
                         value: periodExpense,
                         color: Color(red: 0.9, green: 0.25, blue: 0.3),
                         icon: "arrow.up.right")
            }

            if periodExpense > 0 && period != .day {
                dailySpendingChart
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accentGlow(color: periodNet >= 0 ? .appGreen : Color(red: 0.9, green: 0.25, blue: 0.3), radius: 14)
    }

    private func miniStat(label: String, value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value.currencyFormatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var dailySpendingChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Spending")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(dailySpending) { bar in
                BarMark(
                    x: .value("Day", bar.weekday),
                    y: .value("Spent", bar.amount)
                )
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.9, green: 0.25, blue: 0.3).opacity(0.85),
                                                          Color(red: 0.9, green: 0.4, blue: 0.4).opacity(0.5)],
                                                startPoint: .bottom, endPoint: .top))
                .cornerRadius(3)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .frame(height: 60)
        }
    }

    // MARK: - Quick Actions

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            quickActionButton(label: "Add Income",
                              icon: "plus.circle.fill",
                              color: .appGreen) {
                prefilledType = .income
                showingAdd = true
            }
            quickActionButton(label: "Add Expense",
                              icon: "minus.circle.fill",
                              color: Color(red: 0.9, green: 0.25, blue: 0.3)) {
                prefilledType = .expense
                showingAdd = true
            }
        }
    }

    private var bnplActionButton: some View {
        Button { showingBNPLProviderChoice = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add Buy Now, Pay Later")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(.purple)
            .background(Color.purple.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var debtActionButton: some View {
        Button { showingDebtChoice = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Include Mortgage or Loan")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(Color.appTeal)
            .background(Color.appTeal.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appTeal.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickActionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(label).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Chips

    private var typeFilterChips: some View {
        HStack(spacing: 8) {
            ForEach(TypeFilter.allCases, id: \.self) { filter in
                let selected = typeFilter == filter
                let count = countFor(filter)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { typeFilter = filter }
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(selected ? Color.black.opacity(0.2) : Color.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    .foregroundStyle(selected ? Color.black : Color.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(selected ? .clear : Color.primary.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func countFor(_ filter: TypeFilter) -> Int {
        switch filter {
        case .all:     return periodTransactions.count
        case .income:  return periodTransactions.filter { $0.type == .income }.count
        case .expense: return periodTransactions.filter { $0.type == .expense }.count
        }
    }

    private var periodNoun: String {
        switch period {
        case .day:   return "Today"
        case .week:  return "This Week"
        case .month: return "This Month"
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        VStack(spacing: 16) {
            ForEach(groupedByDay, id: \.0) { day, txs in
                daySection(day: day, transactions: txs)
            }
        }
    }

    private func daySection(day: Date, transactions txs: [Transaction]) -> some View {
        let dayNet = txs.reduce(0.0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        return VStack(spacing: 6) {
            HStack {
                Text(day.formatted(.dateTime.weekday(.wide)))
                    .font(.caption.weight(.semibold))
                Text("·").foregroundStyle(.quaternary)
                Text(day.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text((dayNet >= 0 ? "+" : "") + dayNet.currencyFormatted)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(dayNet >= 0 ? Color.appGreen : Color(red: 0.9, green: 0.25, blue: 0.3))
            }
            .padding(.horizontal, 4)

            ForEach(txs) { tx in
                Button { editingTx = tx } label: {
                    TransactionRow(transaction: tx)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { editingTx = tx } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        BillNotificationManager.cancel(for: tx)
                        withAnimation { modelContext.delete(tx) }
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: typeFilter == .income ? "arrow.down.left.circle"
                  : typeFilter == .expense ? "arrow.up.right.circle"
                  : "list.bullet.clipboard")
                .font(.system(size: 44)).foregroundStyle(.tertiary)
            Text(typeFilter == .income ? "No Income \(periodNoun)"
                 : typeFilter == .expense ? "No Expenses \(periodNoun)"
                 : "No Transactions \(periodNoun)")
                .font(.subheadline.weight(.medium))
            Text(typeFilter == .income ? "Tap Add Income above to log a paycheck or other income."
                 : typeFilter == .expense ? "Tap Add Expense above to log a purchase."
                 : "Tap Add Income or Add Expense above to get started.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    private var color: Color {
        transaction.type == .income ? .appGreen : Color(red: 0.9, green: 0.25, blue: 0.3)
    }
    private var icon: String {
        transaction.type == .income ? "arrow.down.left.circle.fill" : transaction.category.icon
    }
    private var displayName: String {
        if !transaction.name.isEmpty { return transaction.name }
        return transaction.type == .income ? "Income" : transaction.category.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.appTeal)
                    }
                }
                Text(transaction.type == .income ? "Income" : transaction.category.rawValue)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text((transaction.type == .income ? "+" : "−") + transaction.amount.currencyFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
}

// MARK: - Add / Edit Transaction

struct AddEditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var transaction: Transaction? = nil
    var prefilledType: TransactionType = .expense

    @State private var type: TransactionType = .expense
    @State private var name = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var recurringFrequency: PaymentFrequency = .biweekly
    @State private var isScheduled = false
    @State private var dueDate = Date()

    private var isEditing: Bool { transaction != nil }
    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var isValid: Bool { amount > 0 }
    private var typeColor: Color {
        type == .income ? .appGreen : Color(red: 0.9, green: 0.25, blue: 0.3)
    }

    private var quickDates: [(String, Date)] {
        let cal = Calendar.current
        return [
            ("Today", cal.startOfDay(for: Date())),
            ("Yesterday", cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    typeToggle
                    amountInput
                    nameField
                    if type == .expense { categoryGrid }
                    dateField
                    if type == .expense { scheduleBillSection }
                    recurringSection
                    notesField
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .premiumBackground()
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .fontWeight(.semibold)
                        .tint(typeColor)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let tx = transaction {
                    type = tx.type
                    name = tx.name
                    amountText = String(format: "%.2f", tx.amount)
                    category = tx.category
                    date = tx.date
                    notes = tx.notes
                    isRecurring = tx.isRecurring
                    recurringFrequency = tx.recurringFrequency
                    if let due = tx.dueDate {
                        isScheduled = !tx.isPaid
                        dueDate = due
                    }
                } else {
                    type = prefilledType
                }
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 10) {
            typeToggleButton(.expense, label: "Expense", icon: "minus.circle.fill",
                              color: Color(red: 0.9, green: 0.25, blue: 0.3))
            typeToggleButton(.income, label: "Income", icon: "plus.circle.fill",
                              color: .appGreen)
        }
    }

    private func typeToggleButton(_ t: TransactionType, label: String, icon: String, color: Color) -> some View {
        let selected = type == t
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { type = t }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? color : Color.primary.opacity(0.3))
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? color.opacity(0.14) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? color.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount

    private var amountInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(type == .income ? "+$" : "−$")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(typeColor)
                TextField("0.00", text: $amountText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type == .income ? "Source" : "Description")
                .font(.caption).foregroundStyle(.secondary)
            TextField(type == .income ? "e.g. Paycheck, Side hustle" : "e.g. Lunch, Coffee",
                      text: $name)
                .font(.subheadline)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { category = cat }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(cat.rawValue)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? Color.appGreen : Color.primary.opacity(0.7))
                        .background(category == cat ? Color.appGreen.opacity(0.14) : Color.primary.opacity(0.04),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(category == cat ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Date

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(quickDates, id: \.0) { label, d in
                    let selected = Calendar.current.isDate(date, inSameDayAs: d)
                    Button { date = d } label: {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selected ? Color.appGreen.opacity(0.18) : Color.primary.opacity(0.06),
                                        in: Capsule())
                            .foregroundStyle(selected ? Color.appGreen : Color.primary)
                            .overlay(Capsule().strokeBorder(selected ? Color.appGreen.opacity(0.4) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appGreen)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recurring (income only)

    private var availableFrequencies: [PaymentFrequency] {
        // Income usually doesn't recur daily, so hide that case for income type.
        type == .income
            ? [.weekly, .biweekly, .monthly]
            : PaymentFrequency.allCases
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isRecurring.animation()) {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(typeColor)
                    Text(type == .income ? "Repeat this income" : "Repeat this expense")
                        .font(.subheadline.weight(.medium))
                }
            }
            .tint(.appGreen)

            if isRecurring {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(availableFrequencies, id: \.self) { freq in
                            let selected = recurringFrequency == freq
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { recurringFrequency = freq }
                            } label: {
                                Text(freq.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(selected ? Color.appGreen.opacity(0.18) : Color.primary.opacity(0.05),
                                                in: Capsule())
                                    .foregroundStyle(selected ? Color.appGreen : Color.primary)
                                    .overlay(Capsule().strokeBorder(selected ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text(isEditing
                     ? "Editing only affects this entry. Delete and re-add to update future occurrences."
                     : "Adds the next \(recurringFrequency.generationCap) occurrences on the same schedule.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scheduleBillSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isScheduled.animation()) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appGold)
                    Text("Schedule as upcoming bill")
                        .font(.subheadline.weight(.medium))
                }
            }
            .tint(.appGreen)

            if isScheduled {
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    .font(.subheadline)
                Text("Tracked under Upcoming & Overdue on the Dashboard. Tap the row to mark it paid.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Notes

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)").font(.caption).foregroundStyle(.secondary)
            TextField("Any details...", text: $notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func save() {
        let scheduledForLater = isScheduled && type == .expense
        let savedDueDate: Date? = scheduledForLater ? dueDate : nil
        let savedIsPaid: Bool = !scheduledForLater

        var insertedBills: [Transaction] = []

        if let tx = transaction {
            // Cancel existing reminders before mutating — they may no longer apply.
            BillNotificationManager.cancel(for: tx)

            tx.type = type
            tx.name = name
            tx.amount = amount
            tx.category = category
            tx.date = date
            tx.notes = notes
            tx.isRecurring = isRecurring
            tx.recurringFrequency = recurringFrequency
            tx.dueDate = savedDueDate
            tx.isPaid = savedIsPaid

            if !tx.isPaid && tx.dueDate != nil { insertedBills.append(tx) }
        } else {
            let newTx = Transaction(
                name: name,
                amount: amount,
                type: type,
                category: category,
                date: date,
                notes: notes,
                isRecurring: isRecurring,
                recurringFrequency: recurringFrequency,
                dueDate: savedDueDate,
                isPaid: savedIsPaid
            )
            modelContext.insert(newTx)
            if scheduledForLater { insertedBills.append(newTx) }

            if isRecurring {
                let futures = generateFutureOccurrences(scheduledForLater: scheduledForLater)
                if scheduledForLater { insertedBills.append(contentsOf: futures) }
            }
        }
        try? modelContext.save()

        // Schedule notifications outside the SwiftData save — they don't affect persistence.
        Task {
            for bill in insertedBills {
                await BillNotificationManager.schedule(for: bill)
            }
        }

        dismiss()
    }

    @discardableResult
    private func generateFutureOccurrences(scheduledForLater: Bool) -> [Transaction] {
        let cal = Calendar.current
        let count = recurringFrequency.generationCap
        let component = recurringFrequency.calendarComponent
        let value = recurringFrequency.calendarValue

        var inserted: [Transaction] = []
        var nextDate = scheduledForLater ? dueDate : date

        for _ in 0..<count {
            nextDate = cal.date(byAdding: component, value: value, to: nextDate) ?? nextDate
            let newTx = Transaction(
                name: name,
                amount: amount,
                type: type,
                category: category,
                date: nextDate,
                notes: notes,
                isRecurring: true,
                recurringFrequency: recurringFrequency,
                dueDate: scheduledForLater ? nextDate : nil,
                isPaid: !scheduledForLater
            )
            modelContext.insert(newTx)
            inserted.append(newTx)
        }
        return inserted
    }
}

// MARK: - BNPL

enum BNPLProvider {
    static let all = [
        "Affirm",
        "Klarna",
        "Afterpay",
        "Sezzle",
        "Zip (Quadpay)",
        "Apple Pay Later",
        "PayPal Pay in 4",
        "Other"
    ]
}

struct AddBNPLView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let provider: String

    @State private var itemDescription = ""
    @State private var totalAmountText = ""
    @State private var installmentCount = 4
    @State private var firstPaymentDate = Date()
    @State private var frequency: BNPLFrequency = .biweekly

    enum BNPLFrequency: String, CaseIterable {
        case biweekly = "Every 2 Weeks"
        case monthly  = "Monthly"
        var daysBetween: Int { self == .biweekly ? 14 : 30 }
    }

    private let installmentOptions = [2, 3, 4, 6, 12]

    private var total: Double {
        Double(totalAmountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var perPayment: Double {
        installmentCount > 0 ? total / Double(installmentCount) : 0
    }
    private var isValid: Bool {
        total > 0 && !itemDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroPreview
                    itemCard
                    amountCard
                    scheduleCard
                    if isValid { breakdownCard }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .premiumBackground()
            .navigationTitle("\(provider)")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save() }
                        .fontWeight(.semibold).tint(.appGreen)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var heroPreview: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.28), .pink.opacity(0.18)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            Text(itemDescription.isEmpty ? "Buy Now, Pay Later" : itemDescription)
                .font(.headline)
                .foregroundStyle(itemDescription.isEmpty ? .secondary : .primary)
            Text("via \(provider)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var itemCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item").font(.caption).foregroundStyle(.secondary)
            TextField("e.g. New laptop, Travel booking", text: $itemDescription)
                .font(.subheadline)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Amount").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.purple)
                TextField("0", text: $totalAmountText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(.caption).foregroundStyle(.secondary)

            Text("Number of payments").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(installmentOptions, id: \.self) { n in
                    let selected = installmentCount == n
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { installmentCount = n }
                    } label: {
                        Text("\(n)")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? Color.appGreen.opacity(0.18) : Color.primary.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(selected ? Color.appGreen : Color.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(selected ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("Frequency").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(BNPLFrequency.allCases, id: \.self) { f in
                    let selected = frequency == f
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { frequency = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? Color.appGreen.opacity(0.18) : Color.primary.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(selected ? Color.appGreen : Color.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(selected ? Color.appGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
            DatePicker("First payment", selection: $firstPaymentDate, displayedComponents: .date)
                .font(.subheadline)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan Preview").font(.caption.weight(.semibold)).foregroundStyle(.purple)
            HStack {
                statBlock("Per payment", perPayment.currencyFormatted)
                Divider().frame(height: 32)
                statBlock("Payments", "\(installmentCount)")
                Divider().frame(height: 32)
                statBlock("Total", total.currencyFormatted)
            }
            Text("Adds \(installmentCount) expense transactions to your log, one per due date.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let cal = Calendar.current
        let perAmount = perPayment
        var nextDate = firstPaymentDate
        for i in 0..<installmentCount {
            let notes = "\(provider) BNPL · Payment \(i + 1) of \(installmentCount)"
            modelContext.insert(Transaction(
                name: itemDescription.trimmingCharacters(in: .whitespaces),
                amount: perAmount,
                type: .expense,
                category: .debt,
                date: nextDate,
                notes: notes
            ))
            if i < installmentCount - 1 {
                nextDate = cal.date(byAdding: .day, value: frequency.daysBetween, to: nextDate) ?? nextDate
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
