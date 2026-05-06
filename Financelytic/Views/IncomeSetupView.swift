import SwiftUI
import SwiftData

struct IncomeSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var incomeProfiles: [IncomeProfile]

    @State private var amountText = ""
    @State private var frequency: IncomeFrequency = .monthly

    private var existingProfile: IncomeProfile? { incomeProfiles.first }
    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var monthlyEquivalent: Double { amount * frequency.multiplierToMonthly }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Logo hero
                    VStack(spacing: 14) {
                        LogoMark(size: 64)
                            .accentGlow(color: .appTeal, radius: 22)
                        Text(existingProfile == nil ? "Set Your Income" : "Update Income")
                            .font(.title2.bold())
                        Text("Enter your take-home pay after taxes and deductions.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // Amount input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Net Income Amount").font(.caption).foregroundStyle(.secondary)
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
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(frequency == freq ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .foregroundStyle(frequency == freq ? .black : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(frequency == freq ? .clear : .white.opacity(0.1), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .glassCard()

                    // Monthly breakdown
                    if amount > 0 {
                        VStack(spacing: 0) {
                            equivalentRow("Monthly Income", monthlyEquivalent, highlight: true)
                            Divider().background(.white.opacity(0.07))
                            equivalentRow("Annual Income", monthlyEquivalent * 12)
                            Divider().background(.white.opacity(0.07))
                            equivalentRow("Weekly Equivalent", monthlyEquivalent / 4.33)
                        }
                        .glassCard()
                    }

                    // Save button
                    Button { save() } label: {
                        Text(existingProfile == nil ? "Set Income" : "Update Income")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(amount > 0 ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.white.opacity(0.1)))
                            .foregroundStyle(amount > 0 ? .black : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accentGlow(color: .appGreen, radius: amount > 0 ? 14 : 0)
                    }
                    .disabled(amount <= 0)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24).padding(.top, 24)
            }
            .premiumBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let profile = existingProfile {
                    amountText = String(format: "%.2f", profile.amount)
                    frequency = profile.frequency
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
        if let profile = existingProfile {
            profile.amount = amount
            profile.frequency = frequency
            profile.lastUpdated = Date()
        } else {
            modelContext.insert(IncomeProfile(amount: amount, frequency: frequency))
        }
        dismiss()
    }
}
