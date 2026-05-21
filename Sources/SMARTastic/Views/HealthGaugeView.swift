import SwiftUI

struct HealthGaugeView: View {
    let value: Double
    let maxValue: Double
    let label: String
    let color: Color
    var isInverted: Bool = false

    private var progress: Double {
        let p = value / maxValue
        return isInverted ? max(0, min(1, 1 - p)) : max(0, min(1, p))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.5), color]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(isInverted ? "\(Int((1 - progress) * 100))%" : "\(Int(progress * 100))%")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 56, height: 56)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
