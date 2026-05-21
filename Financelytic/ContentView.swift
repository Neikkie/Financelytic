import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appearancePreference") private var appearancePreference: String = "system"
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false

    private var preferredScheme: ColorScheme? {
        switch appearancePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "arrow.left.arrow.right") }
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.appGreen)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .preferredColorScheme(preferredScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenWelcome },
            set: { newValue in if !newValue { hasSeenWelcome = true } }
        )) {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            IncomeProfile.self, Mortgage.self, MortgagePayment.self,
            PersonalLoan.self, LoanPayment.self, Transaction.self
        ], inMemory: true)
}
