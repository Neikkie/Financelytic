import SwiftUI
import SwiftData

struct MortgageView: View {
    @Query private var mortgages: [Mortgage]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if mortgages.isEmpty {
                    VStack(spacing: 24) {
                        LogoMark(size: 64)
                        Text("No Mortgage").font(.title2.bold())
                        Text("Add your mortgage to track your payoff progress and log payments.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                        Button("Add Mortgage") { showingAdd = true }
                            .buttonStyle(.glassProminent)
                            .tint(.appGreen)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .premiumBackground()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(mortgages) { mortgage in
                                NavigationLink {
                                    MortgageDetailView(mortgage: mortgage)
                                } label: {
                                    PremiumMortgageRow(mortgage: mortgage)
                                }
                            }
                        }
                        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 32)
                    }
                    .premiumBackground()
                }
            }
            .navigationTitle("Mortgage")
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
            .sheet(isPresented: $showingAdd) { AddMortgageView() }
        }
    }
}

// MARK: - Row

struct PremiumMortgageRow: View {
    let mortgage: Mortgage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mortgage.lenderName).font(.headline)
                    if !mortgage.propertyAddress.isEmpty {
                        Text(mortgage.propertyAddress).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(mortgage.currentBalance.currencyFormatted)
                        .font(.title3.bold()).foregroundStyle(LinearGradient.accent)
                    Text("remaining").font(.caption2).foregroundStyle(.secondary)
                }
            }
            AccentProgressBar(value: mortgage.payoffProgress)
            HStack {
                Text("\(Int(mortgage.payoffProgress * 100))% paid off")
                    .font(.caption.weight(.medium)).foregroundStyle(Color.appGreen)
                Spacer()
                Text("\(mortgage.monthlyPayment.currencyFormatted)/mo")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .glassCard()
        .accentGlow(color: .appTeal, radius: 12)
    }
}

// MARK: - Detail

struct MortgageDetailView: View {
    @Bindable var mortgage: Mortgage
    @State private var showingAddPayment = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Progress card
                VStack(spacing: 16) {
                    HStack {
                        statBlock("Original", mortgage.originalBalance.currencyFormatted)
                        Divider().frame(height: 44)
                        statBlock("Paid Off", (mortgage.originalBalance - mortgage.currentBalance).currencyFormatted)
                        Divider().frame(height: 44)
                        statBlock("Remaining", mortgage.currentBalance.currencyFormatted, highlight: true)
                    }
                    AccentProgressBar(value: mortgage.payoffProgress, height: 10)
                    HStack {
                        Text("\(Int(mortgage.payoffProgress * 100))% paid")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.appGreen)
                        Spacer()
                        if let date = mortgage.estimatedPayoffDate {
                            Label("Est. payoff \(date, style: .date)", systemImage: "flag.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .glassCard()
                .accentGlow(color: .appTeal, radius: 20)

                // Details
                VStack(spacing: 0) {
                    infoRow("Lender", mortgage.lenderName)
                    sep()
                    infoRow("Interest Rate", "\(mortgage.interestRate)%")
                    sep()
                    infoRow("Monthly Payment", mortgage.monthlyPayment.currencyFormatted)
                    sep()
                    infoRow("Term", "\(mortgage.termYears) years")
                    sep()
                    infoRow("Start Date", mortgage.startDate.formatted(date: .abbreviated, time: .omitted))
                    if !mortgage.propertyAddress.isEmpty {
                        sep()
                        infoRow("Property", mortgage.propertyAddress)
                    }
                }
                .glassCard()

                // Payment history
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Payment History").font(.headline)
                        Spacer()
                        Text("\(mortgage.payments.count) payment\(mortgage.payments.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if mortgage.payments.isEmpty {
                        Text("No payments logged yet.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(mortgage.payments.sorted { $0.date > $1.date }) { payment in
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(payment.date, style: .date)
                                            .font(.subheadline.weight(.medium))
                                        HStack(spacing: 4) {
                                            Text("Principal: \(payment.principalAmount.currencyFormatted)")
                                            Text("·").foregroundStyle(.tertiary)
                                            Text("Interest: \(payment.interestAmount.currencyFormatted)")
                                        }
                                        .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(payment.totalAmount.currencyFormatted)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(LinearGradient.accent)
                                }
                                if !payment.note.isEmpty {
                                    Text(payment.note).font(.caption2).foregroundStyle(.tertiary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                            }
                            if payment.date != mortgage.payments.sorted { $0.date > $1.date }.last?.date {
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
        .navigationTitle("Mortgage Detail")
        .navigationBarTitleDisplayMode(.inline)
        .premiumNavBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddPayment = true } label: {
                    Label("Log Payment", systemImage: "plus")
                        .foregroundStyle(LinearGradient.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddPayment) {
            AddMortgagePaymentView(mortgage: mortgage)
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

    private func sep() -> some View {
        Divider()
    }
}

// MARK: - Add Mortgage

struct AddMortgageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var lenderName = ""
    @State private var propertyAddress = ""
    @State private var originalBalance = ""
    @State private var currentBalance = ""
    @State private var interestRate = ""
    @State private var monthlyPayment = ""
    @State private var startDate = Date()
    @State private var termYears = 30

    private let termOptions = [10, 15, 20, 25, 30]

    private var origAmount: Double {
        Double(originalBalance.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var paymentAmount: Double {
        Double(monthlyPayment.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var rateValue: Double { Double(interestRate) ?? 0 }
    private var isValid: Bool {
        !lenderName.trimmingCharacters(in: .whitespaces).isEmpty &&
        origAmount > 0 && paymentAmount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroPreview
                    lenderCard
                    amountCard
                    paymentCard
                    termCard
                    if isValid { summaryCard }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .premiumBackground()
            .navigationTitle("New Mortgage")
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
                    .fill(LinearGradient(colors: [.indigo.opacity(0.25), .blue.opacity(0.15)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .blue],
                                                    startPoint: .top, endPoint: .bottom))
            }
            Text(lenderName.isEmpty ? "Add Mortgage" : lenderName)
                .font(.headline)
                .foregroundStyle(lenderName.isEmpty ? .secondary : .primary)
            if paymentAmount > 0 {
                Text("\(paymentAmount.currencyFormatted)/mo · \(termYears)-yr term")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var lenderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lender").font(.caption).foregroundStyle(.secondary)
            TextField("Lender (e.g. Chase Bank)", text: $lenderName)
                .font(.subheadline)
            Divider()
            TextField("Property address (optional)", text: $propertyAddress)
                .font(.subheadline)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loan Amount").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                TextField("0", text: $originalBalance)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
            }
            Text("Original loan amount").font(.caption2).foregroundStyle(.tertiary)
            Divider().padding(.top, 4)
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("Current balance", text: $currentBalance)
                    .font(.subheadline)
                    .keyboardType(.decimalPad)
            }
            Text("Leave blank if it's the same as the original").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("Monthly payment", text: $monthlyPayment)
                    .font(.subheadline)
                    .keyboardType(.decimalPad)
            }
            Divider()
            HStack {
                TextField("Interest rate", text: $interestRate)
                    .font(.subheadline)
                    .keyboardType(.decimalPad)
                Text("%").foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var termCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Term").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(termOptions, id: \.self) { years in
                    let selected = termYears == years
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { termYears = years }
                    } label: {
                        Text("\(years)y")
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
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                .font(.subheadline)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var summaryCard: some View {
        let totalMonths = termYears * 12
        let totalCost = paymentAmount * Double(totalMonths)
        let interestCost = max(totalCost - origAmount, 0)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Summary").font(.caption.weight(.semibold)).foregroundStyle(Color.appGreen)
            HStack {
                summaryStat("Total of payments", totalCost.currencyFormatted)
                Divider().frame(height: 32)
                summaryStat("Est. interest", interestCost.currencyFormatted)
            }
        }
        .padding(16)
        .background(Color.appGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.appGreen.opacity(0.25), lineWidth: 1)
        )
    }

    private func summaryStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let curr = currentBalance.isEmpty ? origAmount :
            (Double(currentBalance.replacingOccurrences(of: ",", with: "")) ?? origAmount)
        let mortgage = Mortgage(
            lenderName: lenderName.trimmingCharacters(in: .whitespaces),
            propertyAddress: propertyAddress,
            originalBalance: origAmount,
            currentBalance: curr,
            interestRate: rateValue,
            monthlyPayment: paymentAmount,
            startDate: startDate,
            termYears: termYears
        )
        modelContext.insert(mortgage)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Payment

struct AddMortgagePaymentView: View {
    @Bindable var mortgage: Mortgage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var principalText = ""
    @State private var interestText = ""
    @State private var note = ""

    private var principal: Double { Double(principalText) ?? 0 }
    private var interest: Double { Double(interestText) ?? 0 }
    private var total: Double { principal + interest }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Breakdown") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("Principal Amount", text: $principalText).keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("Interest Amount", text: $interestText).keyboardType(.decimalPad)
                    }
                    if total > 0 {
                        HStack {
                            Text("Total Payment")
                            Spacer()
                            Text(total.currencyFormatted)
                                .fontWeight(.semibold).foregroundStyle(LinearGradient.accent)
                        }
                    }
                }
                Section("Note (optional)") {
                    TextField("e.g. Extra principal payment", text: $note)
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
                        .disabled(principal <= 0)
                }
            }
        }
    }

    private func save() {
        let payment = MortgagePayment(date: date, totalAmount: total,
                                      principalAmount: principal, interestAmount: interest, note: note)
        mortgage.payments.append(payment)
        mortgage.currentBalance = max(mortgage.currentBalance - principal, 0)
        try? modelContext.save()
        dismiss()
    }
}
