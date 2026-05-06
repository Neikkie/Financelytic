import SwiftUI
import SwiftData

struct PersonalLoansView: View {
    @Query private var loans: [PersonalLoan]
    @Query private var incomeProfiles: [IncomeProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var monthlyIncome: Double { incomeProfiles.first?.monthlyAmount ?? 0 }
    private var activeLoans: [PersonalLoan] { loans.filter { !$0.isPaidOff } }
    private var paidLoans: [PersonalLoan]  { loans.filter { $0.isPaidOff  } }
    private var totalOwed: Double { activeLoans.reduce(0) { $0 + $1.currentBalance } }
    private var totalMonthlyCommitment: Double { activeLoans.reduce(0) { $0 + $1.monthlyEquivalent } }

    var body: some View {
        NavigationStack {
            Group {
                if loans.isEmpty {
                    VStack(spacing: 24) {
                        LogoMark(size: 64)
                        Text("No Personal Loans").font(.title2.bold())
                        Text("Track money borrowed from friends and family. Log payments and monitor your payoff progress.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                        Button("Add Loan") { showingAdd = true }
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(LinearGradient.accent)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                            .accentGlow()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .premiumBackground()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if !activeLoans.isEmpty {
                                // Summary
                                summaryCard
                                // Active
                                sectionHeader("Active Loans", count: activeLoans.count)
                                ForEach(activeLoans.sorted { $0.createdDate > $1.createdDate }) { loan in
                                    NavigationLink {
                                        LoanDetailView(loan: loan, monthlyIncome: monthlyIncome)
                                    } label: {
                                        PremiumLoanRow(loan: loan)
                                    }
                                }
                            }
                            if !paidLoans.isEmpty {
                                sectionHeader("Paid Off", count: paidLoans.count)
                                ForEach(paidLoans.sorted { $0.createdDate > $1.createdDate }) { loan in
                                    NavigationLink {
                                        LoanDetailView(loan: loan, monthlyIncome: monthlyIncome)
                                    } label: {
                                        PremiumLoanRow(loan: loan)
                                    }
                                }
                            }
                            Spacer().frame(height: 20)
                        }
                        .padding(.horizontal, 18).padding(.top, 12)
                    }
                    .premiumBackground()
                }
            }
            .navigationTitle("Personal Loans")
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LinearGradient.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddLoanView().preferredColorScheme(.dark) }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Owed").font(.caption).foregroundStyle(.secondary)
                    Text(totalOwed.currencyFormatted)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.warning)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Commitment").font(.caption).foregroundStyle(.secondary)
                    Text(totalMonthlyCommitment.currencyFormatted)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.danger)
                }
            }
            if monthlyIncome > 0 {
                let pct = totalMonthlyCommitment / monthlyIncome * 100
                VStack(spacing: 5) {
                    AccentProgressBar(value: pct / 100, gradient: pct < 20 ? .accent : .warning)
                    HStack {
                        Text("\(pct.percentFormatted) of income").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(pct < 20 ? "Manageable" : "High").font(.caption2.weight(.semibold))
                            .foregroundStyle(pct < 20 ? Color.appGreen : Color.appGold)
                    }
                }
            }
        }
        .glassCard()
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(count)").font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.white.opacity(0.08)).clipShape(Capsule())
            Spacer()
        }
    }
}

// MARK: - Row

struct PremiumLoanRow: View {
    let loan: PersonalLoan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(loan.lenderName).font(.headline)
                    Text(loan.relationship).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if loan.isPaidOff {
                    Label("Paid Off", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.appGreen)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.appGreen.opacity(0.12)).clipShape(Capsule())
                } else {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(loan.currentBalance.currencyFormatted)
                            .font(.title3.bold()).foregroundStyle(LinearGradient.warning)
                        Text("remaining").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if !loan.isPaidOff {
                AccentProgressBar(value: loan.payoffProgress, gradient: .warning)
                HStack {
                    Text("\(Int(loan.payoffProgress * 100))% paid")
                        .font(.caption.weight(.medium)).foregroundStyle(Color.appGold)
                    Spacer()
                    if let due = loan.dueDate {
                        Label("Due \(due, style: .date)", systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Detail

struct LoanDetailView: View {
    @Bindable var loan: PersonalLoan
    let monthlyIncome: Double
    @State private var showingAddPayment = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Progress hero
                VStack(spacing: 16) {
                    HStack {
                        statBlock("Borrowed", loan.originalAmount.currencyFormatted)
                        Divider().frame(height: 44).background(.white.opacity(0.1))
                        statBlock("Paid", loan.totalPaid.currencyFormatted, highlight: true)
                        Divider().frame(height: 44).background(.white.opacity(0.1))
                        statBlock("Remaining", max(loan.currentBalance,0).currencyFormatted)
                    }
                    AccentProgressBar(value: loan.payoffProgress,
                                      height: 10,
                                      gradient: loan.isPaidOff ? .accent : .warning)
                    HStack {
                        Text(loan.isPaidOff ? "Fully paid off!" : "\(Int(loan.payoffProgress * 100))% paid")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(loan.isPaidOff ? Color.appGreen : Color.appGold)
                        Spacer()
                        if let due = loan.dueDate, !loan.isPaidOff {
                            Label("Due \(due, style: .date)", systemImage: "calendar")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .glassCard()
                .accentGlow(color: loan.isPaidOff ? .appGreen : .appGold, radius: 18)

                // Details
                VStack(spacing: 0) {
                    infoRow("Lender", loan.lenderName)
                    sep(); infoRow("Relationship", loan.relationship)
                    sep(); infoRow("Agreed Payment", "\(loan.agreedPaymentAmount.currencyFormatted) \(loan.paymentFrequency.rawValue.lowercased())")
                    sep(); infoRow("Borrowed On", loan.createdDate.formatted(date: .abbreviated, time: .omitted))
                    if monthlyIncome > 0, !loan.isPaidOff {
                        sep()
                        infoRow("% of Monthly Income", (loan.monthlyEquivalent / monthlyIncome * 100).percentFormatted)
                    }
                }
                .glassCard()

                if !loan.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.caption).foregroundStyle(.secondary)
                        Text(loan.notes).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }

                // Payment history
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Payment History").font(.headline)
                        Spacer()
                        Text("\(loan.payments.count) payment\(loan.payments.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if loan.payments.isEmpty {
                        Text("No payments logged yet.").font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
                    } else {
                        let sortedPayments = loan.payments.sorted(by: { $0.date > $1.date })
                        ForEach(sortedPayments) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(payment.date, style: .date).font(.subheadline.weight(.medium))
                                    if !payment.note.isEmpty {
                                        Text(payment.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(payment.amount.currencyFormatted)
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appGreen)
                            }
                            if payment.id != sortedPayments.last?.id {
                                Divider().background(.white.opacity(0.06))
                            }
                        }
                    }
                }
                .glassCard()

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 18).padding(.top, 12)
        }
        .premiumBackground()
        .navigationTitle(loan.lenderName)
        .navigationBarTitleDisplayMode(.inline)
        .premiumNavBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddPayment = true } label: {
                    Label("Log Payment", systemImage: "plus")
                        .foregroundStyle(LinearGradient.accent)
                }
                .disabled(loan.isPaidOff)
            }
        }
        .sheet(isPresented: $showingAddPayment) {
            AddLoanPaymentView(loan: loan).preferredColorScheme(.dark)
        }
    }

    private func statBlock(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(highlight ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.primary))
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }

    private func sep() -> some View { Divider().background(.white.opacity(0.07)) }
}

// MARK: - Add Loan

struct AddLoanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var lenderName = ""
    @State private var relationship = "Friend"
    @State private var amount = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var agreedPayment = ""
    @State private var frequency: PaymentFrequency = .monthly
    @State private var notes = ""

    private let relationships = ["Friend", "Family", "Colleague", "Other"]
    private var isValid: Bool { !lenderName.isEmpty && Double(amount) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lender") {
                    TextField("Name", text: $lenderName)
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { Text($0) }
                    }
                }
                Section("Amount Borrowed") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad)
                    }
                }
                Section("Repayment Plan") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("Agreed payment amount", text: $agreedPayment).keyboardType(.decimalPad)
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PaymentFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("Notes (optional)") {
                    TextField("Agreement details, conditions...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .navigationTitle("Add Personal Loan")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(isValid ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.secondary))
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let loan = PersonalLoan(
            lenderName: lenderName, relationship: relationship,
            originalAmount: Double(amount) ?? 0,
            dueDate: hasDueDate ? dueDate : nil,
            agreedPaymentAmount: Double(agreedPayment) ?? 0,
            paymentFrequency: frequency, notes: notes
        )
        modelContext.insert(loan)
        dismiss()
    }
}

// MARK: - Add Loan Payment

struct AddLoanPaymentView: View {
    @Bindable var loan: PersonalLoan
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var amountText = ""
    @State private var note = ""

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Amount") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText).keyboardType(.decimalPad)
                    }
                    if loan.agreedPaymentAmount > 0 {
                        Button("Use agreed amount (\(loan.agreedPaymentAmount.currencyFormatted))") {
                            amountText = String(format: "%.2f", loan.agreedPaymentAmount)
                        }
                        .font(.subheadline).foregroundStyle(LinearGradient.accent)
                    }
                }
                Section("Note (optional)") {
                    TextField("e.g. Monthly payment", text: $note)
                }
                if amount > 0 {
                    Section {
                        HStack {
                            Text("Remaining After Payment")
                            Spacer()
                            Text(max(loan.currentBalance - amount, 0).currencyFormatted)
                                .fontWeight(.semibold)
                                .foregroundStyle(loan.currentBalance - amount <= 0 ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(LinearGradient.warning))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(amount > 0 ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.secondary))
                        .disabled(amount <= 0)
                }
            }
        }
    }

    private func save() {
        loan.payments.append(LoanPayment(date: date, amount: amount, note: note))
        loan.currentBalance = max(loan.currentBalance - amount, 0)
        dismiss()
    }
}
