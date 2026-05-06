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
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LinearGradient.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddMortgageView().preferredColorScheme(.dark) }
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
                        Divider().frame(height: 44).background(.white.opacity(0.1))
                        statBlock("Paid Off", (mortgage.originalBalance - mortgage.currentBalance).currencyFormatted)
                        Divider().frame(height: 44).background(.white.opacity(0.1))
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
            AddMortgagePaymentView(mortgage: mortgage).preferredColorScheme(.dark)
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
        Divider().background(.white.opacity(0.07))
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

    private var isValid: Bool {
        !lenderName.isEmpty && Double(originalBalance) != nil &&
        Double(interestRate) != nil && Double(monthlyPayment) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lender Info") {
                    TextField("Lender Name (e.g. Chase Bank)", text: $lenderName)
                    TextField("Property Address (optional)", text: $propertyAddress)
                }
                Section("Loan Amounts") {
                    currencyField("Original Loan Amount", text: $originalBalance)
                    currencyField("Current Balance (blank = same)", text: $currentBalance)
                }
                Section("Payment Details") {
                    HStack {
                        TextField("Interest Rate", text: $interestRate).keyboardType(.decimalPad)
                        Text("%").foregroundStyle(.secondary)
                    }
                    currencyField("Monthly Payment", text: $monthlyPayment)
                }
                Section("Term") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Stepper("Term: \(termYears) years", value: $termYears, in: 1...40)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .navigationTitle("Add Mortgage")
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

    private func currencyField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text("$").foregroundStyle(.secondary)
            TextField(placeholder, text: text).keyboardType(.decimalPad)
        }
    }

    private func save() {
        let orig = Double(originalBalance) ?? 0
        let curr = currentBalance.isEmpty ? orig : (Double(currentBalance) ?? orig)
        let mortgage = Mortgage(
            lenderName: lenderName, propertyAddress: propertyAddress,
            originalBalance: orig, currentBalance: curr,
            interestRate: Double(interestRate) ?? 0,
            monthlyPayment: Double(monthlyPayment) ?? 0,
            startDate: startDate, termYears: termYears
        )
        modelContext.insert(mortgage)
        dismiss()
    }
}

// MARK: - Add Payment

struct AddMortgagePaymentView: View {
    @Bindable var mortgage: Mortgage
    @Environment(\.dismiss) private var dismiss

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
            .background(Color.appBg)
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(principal > 0 ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.secondary))
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
        dismiss()
    }
}
