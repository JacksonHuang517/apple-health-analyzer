import SwiftUI
import Charts

struct SummaryTab: View {
    let data: DashboardData
    @Binding var period: TimePeriod
    @Binding var selectedType: WorkoutType?

    private var filtered: [WorkoutRecord] { data.allWorkouts(in: period) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                quickStats
                workoutTypeSelector
                weeklyVolumeChart
                recentWorkouts
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("运动概览")
                .font(.largeTitle.bold())
            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var periodLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return "\(f.string(from: period.startDate)) - \(f.string(from: Date()))"
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        let totalCal = data.totalCalories(in: period)
        let sessions = data.sessionCount(in: period)
        let totalMin = filtered.map(\.durationMin).reduce(0, +)
        let totalDist = filtered.compactMap(\.distanceKm).reduce(0, +)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "总训练", value: "\(sessions)", unit: "次",
                       icon: "flame.fill", color: .orange)
            MetricCard(title: "总时长", value: String(format: "%.0f", totalMin), unit: "分钟",
                       icon: "clock.fill", color: .blue)
            MetricCard(title: "消耗热量", value: String(format: "%.0f", totalCal), unit: "千卡",
                       icon: "bolt.fill", color: .red)
            MetricCard(title: "总距离", value: String(format: "%.1f", totalDist), unit: "公里",
                       icon: "location.fill", color: .green)
        }
    }

    // MARK: - Workout Type Selector

    private var workoutTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "运动类型")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(data.workoutTypes) { type in
                        let count = data.workouts(for: type, in: period).count
                        let totalMin = data.totalDuration(for: type, in: period)
                        WorkoutTypeCard(
                            type: type, count: count, totalMin: totalMin,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Weekly Volume

    private var weeklyVolumeChart: some View {
        let weeklyData = computeWeeklyVolume()

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "每周运动量", subtitle: "分钟/周")

            if weeklyData.isEmpty {
                Text("暂无数据").font(.caption).foregroundStyle(.tertiary)
            } else {
                Chart(weeklyData.indices, id: \.self) { i in
                    BarMark(
                        x: .value("周", weeklyData[i].label),
                        y: .value("分钟", weeklyData[i].value)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(weeklyData.count, 8))) { value in
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func computeWeeklyVolume() -> [(label: String, value: Double)] {
        let cal = Calendar.current
        var weeks: [String: Double] = [:]
        var weekOrder: [String] = []
        let f = DateFormatter()
        f.dateFormat = "M/d"

        for w in filtered {
            let weekStart = cal.dateInterval(of: .weekOfYear, for: w.date)?.start ?? w.date
            let key = f.string(from: weekStart)
            if weeks[key] == nil { weekOrder.append(key) }
            weeks[key, default: 0] += w.durationMin
        }
        return weekOrder.suffix(12).map { (label: $0, value: weeks[$0] ?? 0) }
    }

    // MARK: - Recent Workouts

    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近运动")

            let recent = filtered.sorted { $0.date > $1.date }.prefix(8)
            ForEach(Array(recent)) { w in
                workoutRow(w)
            }
        }
    }

    private func workoutRow(_ w: WorkoutRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(w.type.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: w.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(w.type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(w.type.rawValue)
                    .font(.subheadline.bold())
                Text(w.dateLabel + " · " + String(format: "%.0f分钟", w.durationMin))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", w.activeCal))
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("千卡")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
