import SwiftUI

struct LoadingView: View {
    let progress: Double
    let message: String

    @State private var rotation: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 6)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .cyan, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                if progress < 1.0 {
                    Circle()
                        .fill(.blue.opacity(0.08))
                        .frame(width: 70, height: 70)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()
            Spacer()
        }
        .onAppear { pulse = true }
    }
}
