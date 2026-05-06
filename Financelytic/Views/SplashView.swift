import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var badgeOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                logoMark
                    .padding(.bottom, 32)

                // App name
                VStack(spacing: 10) {
                    Text("Financelytic")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Smart Finance. Real Results.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .opacity(taglineOpacity)
                }
                .opacity(textOpacity)

                Spacer()
                Spacer()

                // Bottom badge
                appleBadge
                    .opacity(badgeOpacity)
                    .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .onAppear { animate() }
    }

    // MARK: - Subviews

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.09, blue: 0.18),
                    Color(red: 0.04, green: 0.18, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.teal.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 500, height: 500)
                .offset(y: -60)
        }
    }

    private var logoMark: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.5), Color.green.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 148, height: 148)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Icon circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.75, blue: 0.55),
                            Color(red: 0.05, green: 0.55, blue: 0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: Color.teal.opacity(0.5), radius: glowRadius, x: 0, y: 8)

            // Icon content
            VStack(spacing: 2) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    Text("$")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
    }

    private var appleBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 12))
            Text("Powered by Apple Intelligence")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.38))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Animation

    private func animate() {
        // Ring pulses in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
            ringScale = 1.05
            ringOpacity = 1
        }
        // Logo springs in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // Glow
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            glowRadius = 24
        }
        // App name
        withAnimation(.easeInOut(duration: 0.55).delay(0.55)) {
            textOpacity = 1
        }
        // Tagline
        withAnimation(.easeInOut(duration: 0.5).delay(0.8)) {
            taglineOpacity = 1
        }
        // Badge
        withAnimation(.easeInOut(duration: 0.5).delay(1.1)) {
            badgeOpacity = 1
        }
    }
}

#Preview {
    SplashView()
}
