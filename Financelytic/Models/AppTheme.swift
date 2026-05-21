import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let appBg      = Color(red: 0.04, green: 0.09, blue: 0.18)
    static let appBg2     = Color(red: 0.04, green: 0.18, blue: 0.22)
    static let appGreen   = Color(red: 0.10, green: 0.75, blue: 0.55)
    static let appTeal    = Color(red: 0.05, green: 0.55, blue: 0.75)
    static let appGold    = Color(red: 0.95, green: 0.78, blue: 0.22)
}

// MARK: - Gradient Tokens

extension LinearGradient {
    static let appBackground = LinearGradient(
        colors: [.appBg, .appBg2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let accent = LinearGradient(
        colors: [.appGreen, .appTeal],
        startPoint: .leading, endPoint: .trailing
    )
    static let accentDiagonal = LinearGradient(
        colors: [.appGreen, .appTeal],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let danger = LinearGradient(
        colors: [Color(red: 0.9, green: 0.2, blue: 0.3), Color(red: 0.7, green: 0.1, blue: 0.2)],
        startPoint: .leading, endPoint: .trailing
    )
    static let warning = LinearGradient(
        colors: [Color(red: 0.95, green: 0.6, blue: 0.1), Color(red: 0.85, green: 0.4, blue: 0.05)],
        startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - View Modifiers

struct PremiumBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if colorScheme == .dark {
                        LinearGradient.appBackground
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.appTeal.opacity(0.14), .clear],
                                center: .center, startRadius: 0, endRadius: 280
                            ))
                            .frame(width: 500, height: 500)
                            .offset(x: 120, y: -200)
                            .blur(radius: 50)
                            .allowsHitTesting(false)
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.appGreen.opacity(0.08), .clear],
                                center: .center, startRadius: 0, endRadius: 200
                            ))
                            .frame(width: 400, height: 400)
                            .offset(x: -140, y: 300)
                            .blur(radius: 50)
                            .allowsHitTesting(false)
                    } else {
                        Color(UIColor.systemGroupedBackground)
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.appTeal.opacity(0.07), .clear],
                                center: .center, startRadius: 0, endRadius: 280
                            ))
                            .frame(width: 500, height: 500)
                            .offset(x: 120, y: -200)
                            .blur(radius: 60)
                            .allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea()
            }
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    var tintOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
            .overlay {
                if tintOpacity > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LinearGradient.accentDiagonal.opacity(tintOpacity))
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func premiumBackground() -> some View { modifier(PremiumBackground()) }

    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16, tint: Double = 0) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding, tintOpacity: tint))
    }

    func accentGlow(color: Color = .appTeal, radius: CGFloat = 14) -> some View {
        shadow(color: color.opacity(0.45), radius: radius, x: 0, y: 6)
    }

    func premiumNavBar() -> some View {
        self.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// MARK: - Logo Mark (flows through entire app)

struct LogoMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient.accentDiagonal)
                .frame(width: size, height: size)
                .shadow(color: .appTeal.opacity(0.45), radius: size * 0.3, y: size * 0.1)

            // Outer ring
            Circle()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)

            VStack(spacing: size * 0.03) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.white)
                Text("$")
                    .font(.system(size: size * 0.18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Accent Progress Bar

struct AccentProgressBar: View {
    let value: Double
    var height: CGFloat = 7
    var cornerRadius: CGFloat = 4
    var gradient: LinearGradient = .accent
    var trackOpacity: Double = 0.12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(trackOpacity * 0.6))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(gradient)
                    .frame(width: geo.size.width * min(max(value, 0), 1), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var gradient: LinearGradient = .accent
    var valueColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(gradient.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(gradient)
            }
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Color.primary))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 108)
        .glassCard()
    }
}
