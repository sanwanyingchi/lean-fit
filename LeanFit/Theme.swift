import SwiftUI
import UIKit

enum LeanFitTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.071, green: 0.063, blue: 0.059, alpha: 1)
            : UIColor(red: 0.969, green: 0.957, blue: 0.945, alpha: 1)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.125, green: 0.114, blue: 0.106, alpha: 1)
            : .white
    })

    static let surfaceMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.169, green: 0.153, blue: 0.141, alpha: 1)
            : UIColor(red: 0.945, green: 0.933, blue: 0.922, alpha: 1)
    })

    static let coral = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.4, blue: 0.29, alpha: 1)
            : UIColor(red: 1, green: 0.294, blue: 0.169, alpha: 1)
    })

    static let coralSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.129, blue: 0.106, alpha: 1)
            : UIColor(red: 1, green: 0.941, blue: 0.922, alpha: 1)
    })

    static let progress = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.259, green: 0.659, blue: 0.38, alpha: 1)
            : UIColor(red: 0.176, green: 0.541, blue: 0.29, alpha: 1)
    })

    static let plum = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.725, green: 0.541, blue: 0.655, alpha: 1)
            : UIColor(red: 0.431, green: 0.251, blue: 0.357, alpha: 1)
    })

    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeanFitTheme.surface, in: RoundedRectangle(cornerRadius: LeanFitTheme.cardRadius, style: .continuous))
    }
}

struct CoralButtonStyle: ButtonStyle {
    let disabled: Bool

    init(disabled: Bool = false) {
        self.disabled = disabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(disabled ? Color.secondary : Color.white)
            .background(disabled ? LeanFitTheme.surfaceMuted : LeanFitTheme.coral)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed && !disabled ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.primary)
            .background(LeanFitTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .foregroundStyle(LeanFitTheme.coral)
            }
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = LeanFitTheme.progress

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }
}

struct InlineError: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(LeanFitTheme.coral)
                .frame(width: 68, height: 68)
                .background(LeanFitTheme.coralSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CoralButtonStyle())
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.82), in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    func leanFitPageBackground() -> some View {
        background(LeanFitTheme.background.ignoresSafeArea())
    }
}
