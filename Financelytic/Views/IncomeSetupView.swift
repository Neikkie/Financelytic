import SwiftUI
import SwiftData

struct IncomeSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var incomeProfiles: [IncomeProfile]

    @State private var showingAdd = false
    @State private var editingProfile: IncomeProfile? = nil

    private var totalMonthly: Double {
        incomeProfiles.reduce(0) { $0 + $1.monthlyAmount }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if !incomeProfiles.isEmpty {
                        summaryCard
                    }

                    if incomeProfiles.isEmpty {
                        emptyCard
                    } else {
                        incomeListCard
                    }

                    Button { showingAdd = true } label: {
                        Label("Add Income Source", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.appGreen)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24).padding(.top, 24)
            }
            .premiumBackground()
            .navigationTitle("Income Sources")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold).tint(.appGreen)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditIncomeView()
            }
            .sheet(item: $editingProfile) { profile in
                AddEditIncomeView(profile: profile)
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 6) {
            Text("Total Monthly Income")
                .font(.caption).foregroundStyle(.secondary)
            Text(totalMonthly.currencyFormatted)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
                .minimumScaleFactor(0.6).lineLimit(1)
            HStack(spacing: 6) {
                Text("\(incomeProfiles.count) source\(incomeProfiles.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("·").font(.caption2).foregroundStyle(.quaternary)
                Text("\((totalMonthly * 12).currencyFormatted)/yr")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .accentGlow(color: .appGreen, radius: 20)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("No Income Sources").font(.subheadline.weight(.medium))
            Text("Add your salary, freelance, rental, or any other take-home income.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }

    // MARK: - List

    private var incomeListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(incomeProfiles.enumerated()), id: \.element.persistentModelID) { idx, profile in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient.accent.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "dollarsign")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LinearGradient.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(profile.amount.currencyFormatted) \(profile.frequency.perPeriodLabel)")
                            .font(.caption).foregroundStyle(.secondary)
                        if profile.frequency != .monthly {
                            Text("\(profile.monthlyAmount.currencyFormatted)/mo")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button { editingProfile = profile } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.primary.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive) {
                        withAnimation { modelContext.delete(profile) }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.9, green: 0.2, blue: 0.3).opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                if idx < incomeProfiles.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Add / Edit Income

struct AddEditIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var profile: IncomeProfile? = nil

    @State private var name = ""
    @State private var amountText = ""
    @State private var frequency: IncomeFrequency = .monthly

    private var isEditing: Bool { profile != nil }
    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var monthlyEquivalent: Double { amount * frequency.multiplierToMonthly }
    private var isValid: Bool { !name.isEmpty && amount > 0 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Source Name").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. Main Job, Freelance, Rental", text: $name)
                            .font(.subheadline)
                            .padding(.vertical, 4)
                    }
                    .glassCard()

                    // Amount
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Take-Home Amount (after tax)").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text("$")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(LinearGradient.accent)
                            TextField("0.00", text: $amountText)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                    .glassCard()

                    // Frequency
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pay Frequency").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(IncomeFrequency.allCases, id: \.self) { freq in
                                Button { frequency = freq } label: {
                                    Text(freq.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(frequency == freq ? Color.appGreen : Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.glass)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(frequency == freq ? Color.appGreen.opacity(0.6) : .clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .glassCard()

                    // Preview
                    if amount > 0 {
                        VStack(spacing: 0) {
                            equivalentRow("Monthly Equivalent", monthlyEquivalent, highlight: true)
                            Divider()
                            equivalentRow("Annual Equivalent", monthlyEquivalent * 12)
                        }
                        .glassCard()
                    }

                    Button(isEditing ? "Save Changes" : "Add Income") { save() }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glassProminent)
                        .tint(.appGreen)
                        .disabled(!isValid)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24).padding(.top, 24)
            }
            .premiumBackground()
            .navigationTitle(isEditing ? "Edit Income" : "Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let p = profile {
                    name = p.name
                    amountText = String(format: "%.2f", p.amount)
                    frequency = p.frequency
                }
            }
        }
    }

    private func equivalentRow(_ label: String, _ value: Double, highlight: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.currencyFormatted)
                .fontWeight(.semibold)
                .foregroundStyle(highlight ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.primary))
        }
        .padding(.vertical, 2)
    }

    private func save() {
        if let p = profile {
            p.name = name
            p.amount = amount
            p.frequency = frequency
            p.lastUpdated = Date()
        } else {
            modelContext.insert(IncomeProfile(name: name, amount: amount, frequency: frequency))
        }
        dismiss()
    }
}
