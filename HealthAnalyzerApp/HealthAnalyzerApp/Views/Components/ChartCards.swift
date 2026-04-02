import SwiftUI
import Charts

struct LineChartCard: View {
    let title: String
    let data: [DailyMetric]
    let unit: String
    let color: Color
    var showAverage: Bool = true

    private var avg: Double {
        guard !data.isEmpty else { return 0 }
        return data.map(\.value).reduce(0, +) / Double(data.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                if !data.isEmpty {
                    Text("平均 \(String(format: "%.1f", avg)) \(unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if data.isEmpty {
                emptyState
            } else {
                Chart(data) { item in
                    AreaMark(
                        x: .value("日期", item.date),
                        y: .value(title, item.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", item.date),
                        y: .value(title, item.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if showAverage {
                        RuleMark(y: .value("平均", avg))
                            .foregroundStyle(color.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(max(data.count / adaptiveStride, 3), 6))) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(adaptiveDateLabel(date))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var adaptiveStride: Int {
        let count = data.count
        if count <= 14 { return 2 }
        if count <= 30 { return 5 }
        if count <= 90 { return 15 }
        if count <= 180 { return 30 }
        return 60
    }

    private func adaptiveDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        if data.count > 180 {
            f.dateFormat = "yy/M"
        } else if data.count > 60 {
            f.dateFormat = "M/d"
        } else {
            f.dateFormat = "M/d"
        }
        return f.string(from: date)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 120)
            Spacer()
        }
    }
}

struct BarChartCard: View {
    let title: String
    let data: [(label: String, value: Double, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())

            if data.isEmpty {
                Text("暂无数据").font(.caption).foregroundStyle(.tertiary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data.indices, id: \.self) { i in
                    BarMark(
                        x: .value("类型", data[i].label),
                        y: .value("数值", data[i].value)
                    )
                    .foregroundStyle(data[i].color)
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RingView: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
