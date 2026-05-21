import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @State private var page = 0

    private struct Page {
        let icon: String
        let title: String
        let body: String
        let color: Color
    }

    private let pages: [Page] = [
        Page(icon: "hand.wave.fill",
             title: "Welcome to Financelytic",
             body: "Your personal finance companion — track every dollar, plan smarter, and stay on top of your bills. Let's take a quick tour.",
             color: .appGreen),
        Page(icon: "arrow.left.arrow.right",
             title: "Log Transactions",
             body: "Use the Transactions tab to record income and expenses. Tap a category, set a date, and optionally schedule a future bill or make it recurring.",
             color: .blue),
        Page(icon: "creditcard.and.123",
             title: "Track Long-Term Debt",
             body: "Add mortgages, personal loans, and Buy Now Pay Later plans from the Transactions tab. Each one feeds your monthly expense total automatically.",
             color: .purple),
        Page(icon: "chart.pie.fill",
             title: "Smart Budgeting",
             body: "The Budget tab shows where your money goes and offers an AI-powered plan tailored to your real spending — including credit-card payoff and BNPL guidance.",
             color: .appTeal),
        Page(icon: "bell.badge.fill",
             title: "Bill Reminders",
             body: "Schedule a bill with a due date and we'll remind you the day before, the day of, and again if it goes overdue. Mark it paid right from the Dashboard.",
             color: .appGold),
        Page(icon: "checkmark.circle.fill",
             title: "You're All Set",
             body: "Visit Settings anytime to manage income sources, mortgages, loans, the 50/30/20 view, and more. Let's get started!",
             color: .appGreen)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [pages[page].color.opacity(0.12), Color.black.opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: page)

            VStack {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") { hasSeenWelcome = true }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: advance) {
                    Text(page == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(.appGreen)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(p.color.opacity(0.18))
                    .frame(width: 120, height: 120)
                Image(systemName: p.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(p.color)
            }
            VStack(spacing: 14) {
                Text(p.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(p.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            hasSeenWelcome = true
        }
    }
}
