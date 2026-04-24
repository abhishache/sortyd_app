import SwiftUI

extension View {
    func shake(amount: CGFloat, shakesPerSecond: Double, isAnimating: Bool) -> some View {
        self.modifier(ShakeEffect(amount: amount, shakesPerSecond: shakesPerSecond, animatableData: isAnimating ? 1 : 0))
            .animation(isAnimating ? .linear(duration: 0.15).repeatForever(autoreverses: true) : .default, value: isAnimating)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var shakesPerSecond: Double
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerSecond)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
