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
    case daily      = "Daily"
    case weekly     = "Weekly"
    case biweekly   = "Bi-Weekly"
    case monthly    = "Monthly"
    case quarterly  = "Quarterly"
    case annually   = "Annually"

    var monthlyMultiplier: Double {
        switch self {
        case .daily:     return 30.0
        case .weekly:    return 52.0 / 12.0
        case .biweekly:  return 26.0 / 12.0
        case .monthly:   return 1.0
        case .quarterly: return 1.0 / 3.0
        case .annually:  return 1.0 / 12.0
        }
    }

    var dayInterval: Int {
        switch self {
        case .daily:     return 1
        case .weekly:    return 7
        case .biweekly:  return 14
        case .monthly:   return 30
        case .quarterly: return 90
        case .annually:  return 365
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily:     return .day
        case .weekly, .biweekly: return .day
        case .monthly:   return .month
        case .quarterly: return .month
        case .annually:  return .year
        }
    }

    var calendarValue: Int {
        switch self {
        case .daily:     return 1
        case .weekly:    return 7
        case .biweekly:  return 14
        case .monthly:   return 1
        case .quarterly: return 3
        case .annually:  return 1
        }
    }

    /// Sensible cap on how many future occurrences to pre-generate.
    var generationCap: Int {
        switch self {
        case .daily:     return 30
        case .weekly:    return 13
        case .biweekly:  return 12
        case .monthly:   return 12
        case .quarterly: return 4
        case .annually:  return 3
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
    var name: String = "Income"
    var amount: Double = 0
    var frequency: IncomeFrequency = IncomeFrequency.monthly
    var lastUpdated: Date = Date()

    init(name: String = "Income", amount: Double, frequency: IncomeFrequency) {
        self.name = name
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

// MARK: - Transaction

enum TransactionType: String, Codable, CaseIterable {
    case income  = "Income"
    case expense = "Expense"
}

@Model
final class Transaction {
    var name: String = ""
    var amount: Double = 0
    var type: TransactionType = TransactionType.expense
    var category: ExpenseCategory = ExpenseCategory.other
    var date: Date = Date()
    var notes: String = ""
    var isRecurring: Bool = false
    var recurringFrequency: PaymentFrequency = PaymentFrequency.monthly
    /// When set, this transaction is a scheduled bill that hasn't happened yet.
    var dueDate: Date? = nil
    /// false for scheduled bills; true for already-happened activity.
    var isPaid: Bool = true

    init(name: String = "",
         amount: Double,
         type: TransactionType,
         category: ExpenseCategory = .other,
         date: Date = Date(),
         notes: String = "",
         isRecurring: Bool = false,
         recurringFrequency: PaymentFrequency = .monthly,
         dueDate: Date? = nil,
         isPaid: Bool = true) {
        self.name = name
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.dueDate = dueDate
        self.isPaid = isPaid
    }

    /// True if this is an unpaid scheduled bill whose due date is in the past.
    var isOverdue: Bool {
        guard !isPaid, let due = dueDate else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    /// True if this is an unpaid scheduled bill due within the next 7 days.
    var isDueSoon: Bool {
        guard !isPaid, let due = dueDate else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let in7 = cal.date(byAdding: .day, value: 7, to: today) ?? today
        return due >= today && due <= in7
    }
}
