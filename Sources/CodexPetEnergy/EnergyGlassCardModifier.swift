import SwiftUI

struct EnergyGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.46),
                                .white.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
    }
}

extension View {
    func energyGlassCard(
        cornerRadius: CGFloat = EnergyVisualStyle.cardCornerRadius
    ) -> some View {
        modifier(EnergyGlassCardModifier(cornerRadius: cornerRadius))
    }
}
