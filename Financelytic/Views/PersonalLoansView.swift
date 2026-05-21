import SwiftUI
import SwiftData

struct PersonalLoansView: View {
    @Query private var loans: [PersonalLoan]
    @Query private var incomeProfiles: [IncomeProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var monthlyIncome: Double { incomeProfiles.reduce(0) { $0 + $1.monthlyAmount } }
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
                            .buttonStyle(.glassProminent)
                            .tint(.appGreen)
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
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                }
            }
            .sheet(isPresented: $showingAdd) { AddLoanView() }
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
                        .minimumScaleFactor(0.6).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Commitment").font(.caption).foregroundStyle(.secondary)
                    Text(totalMonthlyCommitment.currencyFormatted)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.danger)
                        .minimumScaleFactor(0.6).lineLimit(1)
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
                .background(Color.primary.opacity(0.07)).clipShape(Capsule())
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
                        Divider().frame(height: 44)
                        statBlock("Paid", loan.totalPaid.currencyFormatted, highlight: true)
                        Divider().frame(height: 44)
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
                                Divider()
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
            AddLoanPaymentView(loan: loan)
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

    private func sep() -> some View { Divider() }
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

    private struct RelOption {
        let label: String
        let icon: String
    }
    private let relationships: [RelOption] = [
        .init(label: "Friend",    icon: "person.fill"),
        .init(label: "Family",    icon: "person.3.fill"),
        .init(label: "Colleague", icon: "briefcase.fill"),
        .init(label: "Other",     icon: "ellipsis.circle.fill")
    ]

    private var amountValue: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var paymentValue: Double {
        Double(agreedPayment.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var isValid: Bool {
        !lenderName.trimmingCharacters(in: .whitespaces).isEmpty && amountValue > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroPreview
                    lenderCard
                    amountCard
                    repaymentCard
                    notesCard
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .premiumBackground()
            .navigationTitle("New Loan")
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

    // MARK: - Sections

    private var heroPreview: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange.opacity(0.28), .appGold.opacity(0.18)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient.warning)
            }
            Text(lenderName.isEmpty ? "Add Loan" : lenderName)
                .font(.headline)
                .foregroundStyle(lenderName.isEmpty ? .secondary : .primary)
            if amountValue > 0 {
                Text("\(amountValue.currencyFormatted) · \(relationship)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var lenderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Did You Borrow From?")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Name", text: $lenderName)
                .font(.subheadline)
            Divider()
            Text("Relationship").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(relationships, id: \.label) { opt in
                    let selected = relationship == opt.label
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { relationship = opt.label }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(opt.label)
                                .font(.caption2.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amount Borrowed").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.warning)
                TextField("0", text: $amount)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var repaymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repayment Plan").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("Agreed payment", text: $agreedPayment)
                    .font(.subheadline)
                    .keyboardType(.decimalPad)
            }
            Divider()
            Text("Frequency").font(.caption2).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PaymentFrequency.allCases, id: \.self) { freq in
                        let selected = frequency == freq
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { frequency = freq }
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
            Divider()
            Toggle(isOn: $hasDueDate.animation()) {
                Text("Has a due date").font(.subheadline)
            }
            .tint(.appGreen)
            if hasDueDate {
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes (optional)").font(.caption).foregroundStyle(.secondary)
            TextField("Agreement details, conditions...", text: $notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func save() {
        let loan = PersonalLoan(
            lenderName: lenderName.trimmingCharacters(in: .whitespaces),
            relationship: relationship,
            originalAmount: amountValue,
            dueDate: hasDueDate ? dueDate : nil,
            agreedPaymentAmount: paymentValue,
            paymentFrequency: frequency,
            notes: notes
        )
        modelContext.insert(loan)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Loan Payment

struct AddLoanPaymentView: View {
    @Bindable var loan: PersonalLoan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                        .font(.subheadline).tint(.appGreen)
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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .tint(.appGreen)
                        .disabled(amount <= 0)
                }
            }
        }
    }

    private func save() {
        loan.payments.append(LoanPayment(date: date, amount: amount, note: note))
        loan.currentBalance = max(loan.currentBalance - amount, 0)
        try? modelContext.save()
        dismiss()
    }
}
