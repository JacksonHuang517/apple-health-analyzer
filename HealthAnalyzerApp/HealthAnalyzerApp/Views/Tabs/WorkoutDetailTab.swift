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
                insightsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private var hasHR: Bool { workouts.contains { $0.avgHR != nil } }
    private var hasDistance: Bool { workouts.contains { $0.distanceKm != nil } }

    private var xAxisStride: Int {
        let c = workouts.count
        if c <= 14 { return 2 }
        if c <= 30 { return 5 }
        if c <= 60 { return 10 }
        return 20
    }

    private func xAxisDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = workouts.count > 60 ? "M/d" : "M/d"
        return f.string(from: date)
    }

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
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(max(workouts.count / xAxisStride, 3), 6))) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisDateLabel(date))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
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

    // MARK: - Insights

    private var insights: [InsightItem] {
        var items: [InsightItem] = []
        guard workouts.count >= 3 else { return items }

        let cal = Calendar.current
        let weekVolume: [Date: Double] = {
            var dict: [Date: Double] = [:]
            for w in workouts {
                let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: w.date)
                let key = cal.date(from: comp) ?? w.date
                dict[key, default: 0] += w.durationMin
            }
            return dict
        }()
        let sortedWeeks = weekVolume.sorted { $0.key < $1.key }
        let volArr = sortedWeeks.map(\.value)

        let rhr = data.metrics(\.restingHR, in: period)
        if !rhr.isEmpty && sortedWeeks.count >= 3 {
            let weekRHR: [Date: [Double]] = {
                var d: [Date: [Double]] = [:]
                for m in rhr {
                    let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: m.date)
                    let key = cal.date(from: comp) ?? m.date
                    d[key, default: []].append(m.value)
                }
                return d
            }()
            let matched = sortedWeeks.compactMap { wk -> (Double, Double)? in
                guard let vals = weekRHR[wk.key], !vals.isEmpty else { return nil }
                return (wk.value, vals.reduce(0, +) / Double(vals.count))
            }
            if matched.count >= 3 {
                let r = pearsonCorr(matched.map(\.0), matched.map(\.1))
                let rhrFirst = Array(rhr.prefix(min(7, rhr.count))).map(\.value).reduce(0, +) / Double(min(7, rhr.count))
                let rhrLast = Array(rhr.suffix(min(7, rhr.count))).map(\.value).reduce(0, +) / Double(min(7, rhr.count))
                let delta = rhrLast - rhrFirst
                let cls: InsightLevel = delta < -1 ? .good : delta > 1 ? .warn : .neutral
                items.append(InsightItem(level: cls, title: "\(type.rawValue)与静息心率",
                    desc: "静息心率\(delta < 0 ? "下降" : "上升")了\(String(format: "%.1f", abs(delta)))bpm（r=\(String(format: "%.2f", r))）\(delta < -1 ? "，心肺适应性在改善" : "")"))
            }
        }

        let vo2 = data.metrics(\.vo2max, in: period)
        if !vo2.isEmpty && sortedWeeks.count >= 3 {
            let weekVO2: [Date: [Double]] = {
                var d: [Date: [Double]] = [:]
                for m in vo2 {
                    let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: m.date)
                    let key = cal.date(from: comp) ?? m.date
                    d[key, default: []].append(m.value)
                }
                return d
            }()
            let matched = sortedWeeks.compactMap { wk -> (Double, Double)? in
                guard let vals = weekVO2[wk.key], !vals.isEmpty else { return nil }
                return (wk.value, vals.reduce(0, +) / Double(vals.count))
            }
            if matched.count >= 3 {
                let r = pearsonCorr(matched.map(\.0), matched.map(\.1))
                let first = Array(vo2.prefix(3)).map(\.value).reduce(0, +) / Double(min(3, vo2.count))
                let last = Array(vo2.suffix(3)).map(\.value).reduce(0, +) / Double(min(3, vo2.count))
                let delta = last - first
                let cls: InsightLevel = delta > 0.5 ? .good : delta < -0.5 ? .warn : .neutral
                items.append(InsightItem(level: cls, title: "\(type.rawValue)与VO2 Max",
                    desc: "VO2 Max \(delta > 0 ? "提升" : "变化")\(String(format: "%.1f", abs(delta))) mL/kg·min（r=\(String(format: "%.2f", r))）\(delta > 0.5 ? "，有氧能力在提升！" : "")"))
            }
        }

        let hrvData = data.metrics(\.hrv, in: period)
        if !hrvData.isEmpty && sortedWeeks.count >= 3 {
            let weekHRV: [Date: [Double]] = {
                var d: [Date: [Double]] = [:]
                for m in hrvData {
                    let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: m.date)
                    let key = cal.date(from: comp) ?? m.date
                    d[key, default: []].append(m.value)
                }
                return d
            }()
            let matched = sortedWeeks.compactMap { wk -> (Double, Double)? in
                guard let vals = weekHRV[wk.key], !vals.isEmpty else { return nil }
                return (wk.value, vals.reduce(0, +) / Double(vals.count))
            }
            if matched.count >= 3 {
                let r = pearsonCorr(matched.map(\.0), matched.map(\.1))
                let cls: InsightLevel = r > 0.2 ? .good : r < -0.2 ? .warn : .neutral
                items.append(InsightItem(level: cls, title: "\(type.rawValue)与HRV",
                    desc: "运动量与HRV相关系数 \(String(format: "%.2f", r))\(r > 0.2 ? "，运动有助于提升自主神经系统恢复能力" : "")\(r < -0.2 ? "，过度训练可能影响恢复" : "")"))
            }
        }

        if workouts.count >= 5 {
            let durations = workouts.map(\.durationMin)
            let slope = linRegSlope(durations)
            let avg = durations.reduce(0, +) / Double(durations.count)
            let cls: InsightLevel = slope > 0.1 ? .good : slope < -0.1 ? .warn : .neutral
            items.append(InsightItem(level: cls, title: "\(type.rawValue)训练趋势",
                desc: "平均单次\(String(format: "%.0f", avg))分钟，时长斜率\(slope > 0 ? "+" : "")\(String(format: "%.2f", slope))min/次\(slope > 0.1 ? "，训练量在稳步增加" : "")\(slope < -0.1 ? "，运动时长有所减少" : "")"))
        }

        let hrWorkouts = workouts.filter { $0.avgHR != nil }
        if hrWorkouts.count >= 5 {
            let hrs = hrWorkouts.compactMap(\.avgHR)
            let slope = linRegSlope(hrs)
            let cls: InsightLevel = slope < -0.05 ? .good : slope > 0.1 ? .warn : .neutral
            items.append(InsightItem(level: cls, title: "\(type.rawValue)运动心率",
                desc: "运动心率趋势\(slope > 0 ? "+" : "")\(String(format: "%.2f", slope))bpm/次\(slope < -0.05 ? "，同等运动下心率降低，心肺效率在提升" : "")"))
        }

        return items
    }

    @ViewBuilder
    private var insightsSection: some View {
        let items = insights
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "\(type.rawValue) · 身体指标关联洞察")

                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(item.level.color)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.bold())
                            Text(item.desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Stats Helpers

    private func pearsonCorr(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(min(x.count, y.count))
        guard n >= 3 else { return 0 }
        let mx = x.reduce(0, +) / n
        let my = y.reduce(0, +) / n
        var num = 0.0, dx2 = 0.0, dy2 = 0.0
        for i in 0..<Int(n) {
            let dx = x[i] - mx
            let dy = y[i] - my
            num += dx * dy
            dx2 += dx * dx
            dy2 += dy * dy
        }
        let denom = (dx2 * dy2).squareRoot()
        return denom > 0 ? num / denom : 0
    }

    private func linRegSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for (i, v) in values.enumerated() {
            let x = Double(i)
            sumX += x; sumY += v; sumXY += x * v; sumX2 += x * x
        }
        let denom = n * sumX2 - sumX * sumX
        return denom != 0 ? (n * sumXY - sumX * sumY) / denom : 0
    }
}

// MARK: - Insight Model

private enum InsightLevel {
    case good, warn, neutral

    var color: Color {
        switch self {
        case .good: return .green
        case .warn: return .orange
        case .neutral: return .gray
        }
    }
}

private struct InsightItem: Identifiable {
    let id = UUID()
    let level: InsightLevel
    let title: String
    let desc: String
}
