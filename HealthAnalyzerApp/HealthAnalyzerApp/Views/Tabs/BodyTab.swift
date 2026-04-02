import SwiftUI

struct BodyTab: View {
    let data: DashboardData
    @Binding var period: TimePeriod

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                highlightCards
                chartsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("身体指标")
                .font(.largeTitle.bold())
            Text("追踪你的健康趋势")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var highlightCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let rhr = data.health.latestRestingHR {
                MetricCard(title: "静息心率", value: String(format: "%.0f", rhr), unit: "bpm",
                           icon: "heart.fill", color: .red,
                           trend: computeTrend(data.metrics(\.restingHR, in: period)))
            }
            if let hrv = data.health.latestHRV {
                MetricCard(title: "心率变异性", value: String(format: "%.0f", hrv), unit: "ms",
                           icon: "waveform.path.ecg", color: .purple,
                           trend: computeTrend(data.metrics(\.hrv, in: period)))
            }
            if let vo2 = data.health.latestVO2Max {
                MetricCard(title: "VO2 Max", value: String(format: "%.1f", vo2), unit: "mL/kg/min",
                           icon: "lungs.fill", color: .cyan,
                           trend: computeTrend(data.metrics(\.vo2max, in: period)))
            }
            if let weight = data.health.latestWeight {
                MetricCard(title: "体重", value: String(format: "%.1f", weight), unit: "kg",
                           icon: "scalemass.fill", color: .mint,
                           trend: computeTrend(data.metrics(\.bodyMass, in: period)))
            }
            if let avgSteps = data.health.avgSteps {
                MetricCard(title: "日均步数", value: String(format: "%.0f", avgSteps), unit: "步",
                           icon: "figure.walk", color: .teal)
            }
        }
    }

    private var chartsSection: some View {
        VStack(spacing: 16) {
            LineChartCard(
                title: "静息心率", data: data.metrics(\.restingHR, in: period),
                unit: "bpm", color: .red
            )
            LineChartCard(
                title: "心率变异性 (HRV)", data: data.metrics(\.hrv, in: period),
                unit: "ms", color: .purple
            )
            LineChartCard(
                title: "VO2 Max", data: data.metrics(\.vo2max, in: period),
                unit: "mL/kg/min", color: .cyan
            )
            LineChartCard(
                title: "体重", data: data.metrics(\.bodyMass, in: period),
                unit: "kg", color: .mint
            )
            LineChartCard(
                title: "每日步数", data: data.metrics(\.steps, in: period),
                unit: "步", color: .teal, showAverage: true
            )
        }
    }

    private func computeTrend(_ metrics: [DailyMetric]) -> Double? {
        guard metrics.count >= 4 else { return nil }
        let half = metrics.count / 2
        let first = metrics.prefix(half).map(\.value).reduce(0, +) / Double(half)
        let second = metrics.suffix(half).map(\.value).reduce(0, +) / Double(half)
        guard first > 0 else { return nil }
        return (second - first) / first * 100
    }
}
