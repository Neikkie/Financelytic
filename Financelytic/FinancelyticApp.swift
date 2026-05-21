import SwiftUI
import SwiftData

@main
struct FinancelyticApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                Task {
                    // Hold splash long enough for all animations to settle
                    try? await Task.sleep(for: .seconds(2.4))
                    withAnimation(.easeInOut(duration: 0.55)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(for: [
            IncomeProfile.self,
            Mortgage.self,
            MortgagePayment.self,
            PersonalLoan.self,
            LoanPayment.self,
            Transaction.self
        ])
    }
}
