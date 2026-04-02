import SwiftUI
import Charts

struct WorkoutDetailTab: View {
    let data: DashboardData
    let type: WorkoutType
    @Binding var period: TimePeriod

    private var workouts: [WorkoutRecord] {
        data.workouts(for: type, in: period).sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                statsCards
                durationChart
                if hasHR { hrChart }
                if hasDistance { distanceChart; speedChart }
                if type == .running { paceChart }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private var hasHR: Bool { workouts.contains { $0.avgHR != nil } }
    private var hasDistance: Bool { workouts.contains { $0.distanceKm != nil } }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue)
                    .font(.title2.bold())
                Text("\(workouts.count)次训练 · \(period.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var statsCards: some View {
        let totalMin = workouts.map(\.durationMin).reduce(0, +)
        let totalCal = workouts.map(\.activeCal).reduce(0, +)
        let avgDur = workouts.isEmpty ? 0 : totalMin / Double(workouts.count)
        let totalDist = workouts.compactMap(\.distanceKm).reduce(0, +)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "总时长", value: String(format: "%.0f", totalMin), unit: "分钟",
                       icon: "clock.fill", color: .blue)
            MetricCard(title: "平均时长", value: String(format: "%.0f", avgDur), unit: "分钟",
                       icon: "timer", color: .indigo)
            MetricCard(title: "总消耗", value: String(format: "%.0f", totalCal), unit: "千卡",
                       icon: "flame.fill", color: .orange)
            if hasDistance {
                MetricCard(title: "总距离", value: String(format: "%.1f", totalDist), unit: "km",
                           icon: "location.fill", color: .green)
            } else {
                MetricCard(title: "训练次数", value: "\(workouts.count)", unit: "次",
                           icon: "number", color: .purple)
            }
        }
    }

    // MARK: - Charts

    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "训练时长趋势")

            Chart(workouts) { w in
                BarMark(
                    x: .value("日期", w.date, unit: .day),
                    y: .value("分钟", w.durationMin)
                )
                .foregroundStyle(type.color.gradient)
                .cornerRadius(3)
            }
            .frame(height: 160)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var hrChart: some View {
        let hrData = workouts.compactMap { w -> DailyMetric? in
            guard let hr = w.avgHR else { return nil }
            return DailyMetric(date: w.date, value: hr)
        }
        return LineChartCard(title: "平均心率", data: hrData, unit: "bpm", color: .red)
    }

    private var distanceChart: some View {
        let distData = workouts.compactMap { w -> DailyMetric? in
            guard let d = w.distanceKm else { return nil }
            return DailyMetric(date: w.date, value: d)
        }
        return LineChartCard(title: "距离", data: distData, unit: "km", color: .green)
    }

    private var speedChart: some View {
        let speedData = workouts.compactMap { w -> DailyMetric? in
            guard let s = w.avgSpeedKmh, s > 0 else { return nil }
            return DailyMetric(date: w.date, value: s)
        }
        return LineChartCard(title: "平均速度", data: speedData, unit: "km/h", color: .teal)
    }

    private var paceChart: some View {
        let paceData = workouts.compactMap { w -> DailyMetric? in
            guard let p = w.avgPaceMinKm, p > 0 else { return nil }
            return DailyMetric(date: w.date, value: p)
        }
        return LineChartCard(title: "配速", data: paceData, unit: "min/km", color: .blue)
    }
}
