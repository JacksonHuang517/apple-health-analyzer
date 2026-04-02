import SwiftUI

struct BodyTab: View {
    let data: DashboardData
    @Binding var period: TimePeriod

    @State private var section: BodySection = .vitals

    enum BodySection: String, CaseIterable {
        case vitals = "核心指标"
        case mobility = "运动能力"
        case body = "身体成分"
        case activity = "活动量"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                sectionPicker
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

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BodySection.allCases, id: \.self) { s in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { section = s }
                    } label: {
                        Text(s.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(section == s ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(section == s ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var highlightCards: some View {
        switch section {
        case .vitals:
            vitalsHighlight
        case .mobility:
            mobilityHighlight
        case .body:
            bodyHighlight
        case .activity:
            activityHighlight
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        switch section {
        case .vitals:
            vitalsCharts
        case .mobility:
            mobilityCharts
        case .body:
            bodyCharts
        case .activity:
            activityCharts
        }
    }

    // MARK: - Vitals

    private var vitalsHighlight: some View {
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
            let respData = data.metrics(\.respiratoryRate, in: period)
            if let resp = respData.last?.value {
                MetricCard(title: "呼吸频率", value: String(format: "%.1f", resp), unit: "次/分",
                           icon: "wind", color: .indigo,
                           trend: computeTrend(respData))
            }
        }
    }

    private var vitalsCharts: some View {
        VStack(spacing: 16) {
            LineChartCard(title: "静息心率", data: data.metrics(\.restingHR, in: period), unit: "bpm", color: .red)
            LineChartCard(title: "心率变异性 (HRV)", data: data.metrics(\.hrv, in: period), unit: "ms", color: .purple)
            LineChartCard(title: "VO2 Max", data: data.metrics(\.vo2max, in: period), unit: "mL/kg/min", color: .cyan)
            LineChartCard(title: "呼吸频率", data: data.metrics(\.respiratoryRate, in: period), unit: "次/分", color: .indigo)
        }
    }

    // MARK: - Mobility

    private var mobilityHighlight: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            let asymData = data.metrics(\.walkAsymmetry, in: period)
            if let v = asymData.last?.value {
                MetricCard(title: "步伐不对称性", value: String(format: "%.1f", v * 100), unit: "%",
                           icon: "figure.walk.motion", color: .orange,
                           trend: computeTrend(asymData))
            }
            let dsData = data.metrics(\.walkDoubleSupport, in: period)
            if let v = dsData.last?.value {
                MetricCard(title: "双脚支撑", value: String(format: "%.1f", v * 100), unit: "%",
                           icon: "shoe.2.fill", color: .brown,
                           trend: computeTrend(dsData))
            }
            let spdData = data.metrics(\.walkSpeed, in: period)
            if let v = spdData.last?.value {
                MetricCard(title: "步行速度", value: String(format: "%.2f", v), unit: "m/s",
                           icon: "speedometer", color: .teal,
                           trend: computeTrend(spdData))
            }
            let lenData = data.metrics(\.walkStepLength, in: period)
            if let v = lenData.last?.value {
                MetricCard(title: "步长", value: String(format: "%.0f", v * 100), unit: "cm",
                           icon: "ruler", color: .green,
                           trend: computeTrend(lenData))
            }
        }
    }

    private var mobilityCharts: some View {
        VStack(spacing: 16) {
            LineChartCard(title: "步伐不对称性", data: data.metrics(\.walkAsymmetry, in: period).map {
                DailyMetric(date: $0.date, value: $0.value * 100)
            }, unit: "%", color: .orange)
            LineChartCard(title: "双脚支撑时间", data: data.metrics(\.walkDoubleSupport, in: period).map {
                DailyMetric(date: $0.date, value: $0.value * 100)
            }, unit: "%", color: .brown)
            LineChartCard(title: "步行速度", data: data.metrics(\.walkSpeed, in: period), unit: "m/s", color: .teal)
            LineChartCard(title: "步长", data: data.metrics(\.walkStepLength, in: period).map {
                DailyMetric(date: $0.date, value: $0.value * 100)
            }, unit: "cm", color: .green)
        }
    }

    // MARK: - Body Composition

    private var bodyHighlight: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let weight = data.health.latestWeight {
                MetricCard(title: "体重", value: String(format: "%.1f", weight), unit: "kg",
                           icon: "scalemass.fill", color: .mint,
                           trend: computeTrend(data.metrics(\.bodyMass, in: period)))
            }
            if let bf = data.health.latestBodyFat {
                MetricCard(title: "体脂率", value: String(format: "%.1f", bf * 100), unit: "%",
                           icon: "flame.fill", color: .orange,
                           trend: computeTrend(data.metrics(\.bodyFat, in: period)))
            }
            if let bmiVal = data.health.latestBMI {
                MetricCard(title: "BMI", value: String(format: "%.1f", bmiVal), unit: "",
                           icon: "person.fill", color: .blue,
                           trend: computeTrend(data.metrics(\.bmi, in: period)))
            }
        }
    }

    private var bodyCharts: some View {
        VStack(spacing: 16) {
            LineChartCard(title: "体重", data: data.metrics(\.bodyMass, in: period), unit: "kg", color: .mint)
            LineChartCard(title: "体脂率", data: data.metrics(\.bodyFat, in: period).map {
                DailyMetric(date: $0.date, value: $0.value * 100)
            }, unit: "%", color: .orange)
            LineChartCard(title: "BMI", data: data.metrics(\.bmi, in: period), unit: "", color: .blue)
        }
    }

    // MARK: - Activity

    private var activityHighlight: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let avgSteps = data.health.avgSteps {
                MetricCard(title: "日均步数", value: String(format: "%.0f", avgSteps), unit: "步",
                           icon: "figure.walk", color: .teal)
            }
            let standData = data.metrics(\.standTime, in: period)
            if let v = standData.last?.value {
                MetricCard(title: "站立时间", value: String(format: "%.0f", v), unit: "分钟",
                           icon: "figure.stand", color: .green,
                           trend: computeTrend(standData))
            }
            let distData = data.metrics(\.walkRunDistance, in: period)
            if let v = distData.last?.value {
                MetricCard(title: "步行距离", value: String(format: "%.1f", v / 1000), unit: "km",
                           icon: "map.fill", color: .blue)
            }
            let energyData = data.metrics(\.activeEnergy, in: period)
            if let v = energyData.last?.value {
                MetricCard(title: "活动热量", value: String(format: "%.0f", v), unit: "kcal",
                           icon: "flame.fill", color: .red,
                           trend: computeTrend(energyData))
            }
        }
    }

    private var activityCharts: some View {
        VStack(spacing: 16) {
            LineChartCard(title: "每日步数", data: data.metrics(\.steps, in: period), unit: "步", color: .teal, showAverage: true)
            LineChartCard(title: "活动热量", data: data.metrics(\.activeEnergy, in: period), unit: "kcal", color: .red, showAverage: true)
            LineChartCard(title: "站立时间", data: data.metrics(\.standTime, in: period), unit: "分钟", color: .green)
            LineChartCard(title: "步行+跑步距离", data: data.metrics(\.walkRunDistance, in: period).map {
                DailyMetric(date: $0.date, value: $0.value / 1000)
            }, unit: "km", color: .blue)
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
