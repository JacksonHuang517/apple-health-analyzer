import SwiftUI
import Charts

struct SleepTab: View {
    let data: DashboardData
    @Binding var period: TimePeriod

    private var sleepData: [SleepDay] {
        let start = period.startDate
        return data.health.sleep.filter { $0.date >= start }
    }

    private var avgTotal: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.map(\.totalMin).reduce(0, +) / Double(sleepData.count)
    }

    private var avgQuality: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.map(\.qualityScore).reduce(0, +) / Double(sleepData.count)
    }

    private var avgDeep: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.map(\.deepMin).reduce(0, +) / Double(sleepData.count)
    }

    private var avgRem: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.map(\.remMin).reduce(0, +) / Double(sleepData.count)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                highlightCards
                if !sleepData.isEmpty {
                    sleepDurationChart
                    sleepStagesChart
                    sleepQualityChart
                    exerciseImpactSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("睡眠分析")
                .font(.largeTitle.bold())
            Text("了解你的睡眠质量与运动的关系")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Highlights

    private var highlightCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "平均睡眠", value: formatHM(avgTotal), unit: "",
                icon: "bed.double.fill", color: .indigo
            )
            MetricCard(
                title: "睡眠质量", value: String(format: "%.0f", avgQuality), unit: "分",
                icon: "star.fill", color: qualityColor(avgQuality)
            )
            MetricCard(
                title: "深度睡眠", value: String(format: "%.0f", avgDeep), unit: "分钟",
                icon: "moon.zzz.fill", color: .blue
            )
            MetricCard(
                title: "REM 睡眠", value: String(format: "%.0f", avgRem), unit: "分钟",
                icon: "eye.fill", color: .purple
            )
        }
    }

    // MARK: - Sleep Duration Chart

    private var sleepDurationChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每日睡眠时长")
                .font(.subheadline.bold())

            Chart(sleepData) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("时长", day.totalMin / 60.0)
                )
                .foregroundStyle(
                    .linearGradient(colors: [.indigo, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(3)

                RuleMark(y: .value("7h", 7))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .leading) {
                        Text("7h").font(.system(size: 8)).foregroundStyle(.green)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0fh", v)).font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(max(sleepData.count / xStride, 3), 6))) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xLabel(date)).font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sleep Stages

    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("睡眠阶段构成")
                .font(.subheadline.bold())

            let avgData: [(String, Double, Color)] = [
                ("深度", avgDeep, .blue),
                ("REM", avgRem, .purple),
                ("核心", sleepData.isEmpty ? 0 : sleepData.map(\.coreMin).reduce(0, +) / Double(sleepData.count), .cyan),
                ("清醒", sleepData.isEmpty ? 0 : sleepData.map(\.awakeMin).reduce(0, +) / Double(sleepData.count), .orange),
            ]

            Chart(avgData, id: \.0) { item in
                SectorMark(
                    angle: .value(item.0, item.1),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(item.2)
                .cornerRadius(4)
            }
            .frame(height: 180)

            HStack(spacing: 16) {
                ForEach(avgData, id: \.0) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.2).frame(width: 8, height: 8)
                        Text("\(item.0) \(String(format: "%.0f", item.1))分钟")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sleep Quality Trend

    private var sleepQualityChart: some View {
        LineChartCard(
            title: "睡眠质量趋势",
            data: sleepData.map { DailyMetric(date: $0.date, value: $0.qualityScore) },
            unit: "分", color: .indigo, showAverage: true
        )
    }

    // MARK: - Exercise Impact on Sleep

    private var exerciseImpactSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("运动强度 vs 睡眠", systemImage: "figure.run.circle.fill")
                    .font(.headline)
                Text("分析运动对当晚睡眠的影响")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            intensityVsSleepChart
            intensityVsDeepChart
            exerciseSleepInsights
        }
    }

    private var intensityVsSleepChart: some View {
        let paired = pairedExerciseSleep
        return VStack(alignment: .leading, spacing: 10) {
            Text("运动热量 vs 睡眠时长")
                .font(.subheadline.bold())

            if paired.isEmpty {
                emptyPairedState
            } else {
                Chart(paired, id: \.date) { item in
                    PointMark(
                        x: .value("运动热量", item.cal),
                        y: .value("睡眠", item.sleepHours)
                    )
                    .foregroundStyle(.indigo.opacity(0.7))
                    .symbolSize(30)
                }
                .chartXAxisLabel("活动热量 (kcal)")
                .chartYAxisLabel("睡眠 (h)")
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))").font(.caption2) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel { if let v = value.as(Double.self) { Text(String(format: "%.1f", v)).font(.caption2) } }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var intensityVsDeepChart: some View {
        let paired = pairedExerciseSleep
        return VStack(alignment: .leading, spacing: 10) {
            Text("运动热量 vs 深度睡眠")
                .font(.subheadline.bold())

            if paired.isEmpty {
                emptyPairedState
            } else {
                Chart(paired, id: \.date) { item in
                    PointMark(
                        x: .value("运动热量", item.cal),
                        y: .value("深睡", item.deepMin)
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                    .symbolSize(30)
                }
                .chartXAxisLabel("活动热量 (kcal)")
                .chartYAxisLabel("深度睡眠 (分钟)")
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))").font(.caption2) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))").font(.caption2) } }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Insights

    private var exerciseSleepInsights: some View {
        let paired = pairedExerciseSleep
        guard !paired.isEmpty else { return AnyView(EmptyView()) }

        let medianCal = paired.map(\.cal).sorted()[paired.count / 2]
        let highDays = paired.filter { $0.cal >= medianCal }
        let lowDays = paired.filter { $0.cal < medianCal }

        let highSleep = highDays.isEmpty ? 0 : highDays.map(\.sleepHours).reduce(0, +) / Double(highDays.count)
        let lowSleep = lowDays.isEmpty ? 0 : lowDays.map(\.sleepHours).reduce(0, +) / Double(lowDays.count)
        let highDeep = highDays.isEmpty ? 0 : highDays.map(\.deepMin).reduce(0, +) / Double(highDays.count)
        let lowDeep = lowDays.isEmpty ? 0 : lowDays.map(\.deepMin).reduce(0, +) / Double(lowDays.count)
        let highQuality = highDays.isEmpty ? 0 : highDays.map(\.quality).reduce(0, +) / Double(highDays.count)
        let lowQuality = lowDays.isEmpty ? 0 : lowDays.map(\.quality).reduce(0, +) / Double(lowDays.count)

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("运动与睡眠洞察")
                    .font(.subheadline.bold())

                insightRow(
                    icon: highSleep > lowSleep ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: highSleep > lowSleep ? .green : .orange,
                    text: "高强度运动日平均睡眠 \(String(format: "%.1f", highSleep))h，低强度日 \(String(format: "%.1f", lowSleep))h"
                )
                insightRow(
                    icon: highDeep > lowDeep ? "moon.zzz.fill" : "moon.fill",
                    color: highDeep > lowDeep ? .blue : .orange,
                    text: "高强度日深度睡眠 \(String(format: "%.0f", highDeep))分钟，低强度日 \(String(format: "%.0f", lowDeep))分钟"
                )
                insightRow(
                    icon: highQuality > lowQuality ? "star.fill" : "star.leadinghalf.filled",
                    color: highQuality > lowQuality ? .yellow : .gray,
                    text: "高强度日睡眠质量 \(String(format: "%.0f", highQuality))分，低强度日 \(String(format: "%.0f", lowQuality))分"
                )

                let restDays = pairedRestDays
                if !restDays.isEmpty {
                    let restSleep = restDays.map(\.sleepHours).reduce(0, +) / Double(restDays.count)
                    insightRow(
                        icon: "bed.double.fill",
                        color: .indigo,
                        text: "无运动的休息日平均睡眠 \(String(format: "%.1f", restSleep))h"
                    )
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private struct PairedDay {
        let date: Date
        let cal: Double
        let sleepHours: Double
        let deepMin: Double
        let quality: Double
    }

    private var pairedExerciseSleep: [PairedDay] {
        let cal = Calendar.current
        let start = period.startDate
        let workoutsInPeriod = data.workouts.filter { $0.date >= start }

        var calByDate: [String: Double] = [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        for w in workoutsInPeriod {
            let key = df.string(from: w.date)
            calByDate[key, default: 0] += w.activeCal
        }

        return sleepData.compactMap { sleep in
            let key = df.string(from: sleep.date)
            guard let dayCal = calByDate[key], dayCal > 0 else { return nil }
            return PairedDay(
                date: sleep.date,
                cal: dayCal,
                sleepHours: sleep.totalMin / 60.0,
                deepMin: sleep.deepMin,
                quality: sleep.qualityScore
            )
        }
    }

    private var pairedRestDays: [PairedDay] {
        let cal = Calendar.current
        let start = period.startDate
        let workoutsInPeriod = data.workouts.filter { $0.date >= start }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let workoutDates = Set(workoutsInPeriod.map { df.string(from: $0.date) })

        return sleepData.compactMap { sleep in
            let key = df.string(from: sleep.date)
            guard !workoutDates.contains(key), sleep.totalMin > 0 else { return nil }
            return PairedDay(date: sleep.date, cal: 0, sleepHours: sleep.totalMin / 60.0, deepMin: sleep.deepMin, quality: sleep.qualityScore)
        }
    }

    private func qualityColor(_ score: Double) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .yellow }
        return .orange
    }

    private func formatHM(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return "\(h)h\(m)m"
    }

    private var xStride: Int {
        let count = sleepData.count
        if count <= 14 { return 2 }
        if count <= 30 { return 5 }
        if count <= 90 { return 15 }
        return 30
    }

    private func xLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = sleepData.count > 180 ? "yy/M" : "M/d"
        return f.string(from: date)
    }

    private var emptyPairedState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.dots.scatter")
                    .font(.title3).foregroundStyle(.quaternary)
                Text("暂无配对数据")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .frame(height: 120)
            Spacer()
        }
    }
}
