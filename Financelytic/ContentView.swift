import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle.fill") }
            MortgageView()
                .tabItem { Label("Mortgage", systemImage: "building.2.fill") }
            PersonalLoansView()
                .tabItem { Label("Loans", systemImage: "person.2.fill") }
        }
        .tint(.appGreen)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            IncomeProfile.self, Mortgage.self, MortgagePayment.self,
            PersonalLoan.self, LoanPayment.self, Expense.self
        ], inMemory: true)
}
