import Foundation
import SwiftData

// MARK: - Enums

enum IncomeFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-Weekly"
    case monthly = "Monthly"

    var multiplierToMonthly: Double {
        switch self {
        case .weekly:   return 52.0 / 12.0
        case .biweekly: return 26.0 / 12.0
        case .monthly:  return 1.0
        }
    }

    var perPeriodLabel: String {
        switch self {
        case .weekly:   return "per week"
        case .biweekly: return "every 2 weeks"
        case .monthly:  return "per month"
        }
    }
}

enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly     = "Weekly"
    case biweekly   = "Bi-Weekly"
    case monthly    = "Monthly"
    case quarterly  = "Quarterly"
    case annually   = "Annually"

    var monthlyMultiplier: Double {
        switch self {
        case .weekly:    return 52.0 / 12.0
        case .biweekly:  return 26.0 / 12.0
        case .monthly:   return 1.0
        case .quarterly: return 1.0 / 3.0
        case .annually:  return 1.0 / 12.0
        }
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case housing       = "Housing"
    case utilities     = "Utilities"
    case food          = "Food & Groceries"
    case transportation = "Transportation"
    case insurance     = "Insurance"
    case entertainment = "Entertainment"
    case subscription  = "Subscriptions"
    case debt          = "Debt Payment"
    case healthcare    = "Healthcare"
    case other         = "Other"

    var icon: String {
        switch self {
        case .housing:        return "house.fill"
        case .utilities:      return "bolt.fill"
        case .food:           return "cart.fill"
        case .transportation: return "car.fill"
        case .insurance:      return "shield.fill"
        case .entertainment:  return "film.fill"
        case .subscription:   return "repeat"
        case .debt:           return "creditcard.fill"
        case .healthcare:     return "heart.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }

    var color: CategoryColor {
        switch self {
        case .housing:        return .blue
        case .utilities:      return .yellow
        case .food:           return .green
        case .transportation: return .orange
        case .insurance:      return .purple
        case .entertainment:  return .pink
        case .subscription:   return .teal
        case .debt:           return .red
        case .healthcare:     return .mint
        case .other:          return .gray
        }
    }
}

enum CategoryColor: String, Codable {
    case blue, yellow, green, orange, purple, pink, teal, red, mint, gray
}

// MARK: - SwiftData Models

@Model
final class IncomeProfile {
    var amount: Double
    var frequency: IncomeFrequency
    var lastUpdated: Date

    init(amount: Double, frequency: IncomeFrequency) {
        self.amount = amount
        self.frequency = frequency
        self.lastUpdated = Date()
    }

    var monthlyAmount: Double { amount * frequency.multiplierToMonthly }
    var annualAmount: Double  { monthlyAmount * 12 }
    var weeklyAmount: Double  { monthlyAmount / 4.33 }
}

@Model
final class Mortgage {
    var lenderName: String
    var propertyAddress: String
    var originalBalance: Double
    var currentBalance: Double
    var interestRate: Double
    var monthlyPayment: Double
    var startDate: Date
    var termYears: Int
    @Relationship(deleteRule: .cascade) var payments: [MortgagePayment]

    init(lenderName: String, propertyAddress: String, originalBalance: Double,
         currentBalance: Double, interestRate: Double, monthlyPayment: Double,
         startDate: Date, termYears: Int) {
        self.lenderName = lenderName
        self.propertyAddress = propertyAddress
        self.originalBalance = originalBalance
        self.currentBalance = currentBalance
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.startDate = startDate
        self.termYears = termYears
        self.payments = []
    }

    var payoffProgress: Double {
        guard originalBalance > 0 else { return 0 }
        return min(max((originalBalance - currentBalance) / originalBalance, 0), 1)
    }

    var estimatedPayoffDate: Date? {
        guard monthlyPayment > 0, currentBalance > 0 else { return nil }
        let monthlyRate = interestRate / 100.0 / 12.0
        let months: Double
        if monthlyRate < 0.0001 {
            months = currentBalance / monthlyPayment
        } else {
            let ratio = monthlyRate * currentBalance / monthlyPayment
            guard ratio < 1 else { return nil }
            months = -log(1.0 - ratio) / log(1.0 + monthlyRate)
        }
        return Calendar.current.date(byAdding: .month, value: Int(ceil(months)), to: Date())
    }
}

@Model
final class MortgagePayment {
    var date: Date
    var totalAmount: Double
    var principalAmount: Double
    var interestAmount: Double
    var note: String

    init(date: Date, totalAmount: Double, principalAmount: Double, interestAmount: Double, note: String = "") {
        self.date = date
        self.totalAmount = totalAmount
        self.principalAmount = principalAmount
        self.interestAmount = interestAmount
        self.note = note
    }
}

@Model
final class PersonalLoan {
    var lenderName: String
    var relationship: String
    var originalAmount: Double
    var currentBalance: Double
    var dueDate: Date?
    var agreedPaymentAmount: Double
    var paymentFrequency: PaymentFrequency
    var notes: String
    var createdDate: Date
    @Relationship(deleteRule: .cascade) var payments: [LoanPayment]

    init(lenderName: String, relationship: String, originalAmount: Double,
         dueDate: Date? = nil, agreedPaymentAmount: Double = 0,
         paymentFrequency: PaymentFrequency = .monthly, notes: String = "") {
        self.lenderName = lenderName
        self.relationship = relationship
        self.originalAmount = originalAmount
        self.currentBalance = originalAmount
        self.dueDate = dueDate
        self.agreedPaymentAmount = agreedPaymentAmount
        self.paymentFrequency = paymentFrequency
        self.notes = notes
        self.createdDate = Date()
        self.payments = []
    }

    var payoffProgress: Double {
        guard originalAmount > 0 else { return 1 }
        return min(max((originalAmount - max(currentBalance, 0)) / originalAmount, 0), 1)
    }

    var isPaidOff: Bool { currentBalance <= 0 }
    var totalPaid: Double { payments.reduce(0) { $0 + $1.amount } }

    var monthlyEquivalent: Double {
        agreedPaymentAmount * paymentFrequency.monthlyMultiplier
    }
}

@Model
final class LoanPayment {
    var date: Date
    var amount: Double
    var note: String

    init(date: Date, amount: Double, note: String = "") {
        self.date = date
        self.amount = amount
        self.note = note
    }
}

@Model
final class Expense {
    var name: String
    var category: ExpenseCategory
    var amount: Double
    var dueDate: Date
    var isRecurring: Bool
    var recurringStartDate: Date?
    var recurringEndDate: Date?
    var recurringFrequency: PaymentFrequency?
    var isPaid: Bool
    var notes: String
    var createdDate: Date

    init(name: String, category: ExpenseCategory, amount: Double, dueDate: Date,
         isRecurring: Bool = false, recurringStartDate: Date? = nil,
         recurringEndDate: Date? = nil, recurringFrequency: PaymentFrequency? = nil,
         notes: String = "") {
        self.name = name
        self.category = category
        self.amount = amount
        self.dueDate = dueDate
        self.isRecurring = isRecurring
        self.recurringStartDate = recurringStartDate
        self.recurringEndDate = recurringEndDate
        self.recurringFrequency = recurringFrequency
        self.isPaid = false
        self.notes = notes
        self.createdDate = Date()
    }

    var isOverdue: Bool {
        !isPaid && dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueSoon: Bool {
        guard !isPaid else { return false }
        let sevenDays = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return dueDate >= Calendar.current.startOfDay(for: Date()) && dueDate <= sevenDays
    }
}

// MARK: - Formatting Helpers

extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var percentFormatted: String {
        String(format: "%.1f%%", self)
    }
}
