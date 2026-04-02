import SwiftUI

enum BodyState: String {
    case excellent = "状态极佳"
    case good = "状态良好"
    case normal = "状态一般"
    case tired = "需要休息"
    case noData = "暂无数据"

    var icon: String {
        switch self {
        case .excellent: return "sparkles"
        case .good: return "sun.max.fill"
        case .normal: return "cloud.sun.fill"
        case .tired: return "moon.zzz.fill"
        case .noData: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .normal: return .orange
        case .tired: return .red
        case .noData: return .gray
        }
    }

    var gradient: [Color] {
        switch self {
        case .excellent: return [Color(red: 0.2, green: 0.85, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.3)]
        case .good: return [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.15, green: 0.4, blue: 0.9)]
        case .normal: return [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 0.95, green: 0.5, blue: 0.15)]
        case .tired: return [Color(red: 1.0, green: 0.35, blue: 0.3), Color(red: 0.85, green: 0.2, blue: 0.2)]
        case .noData: return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
    }

    var advice: String {
        switch self {
        case .excellent: return "身体恢复充分，适合高强度训练"
        case .good: return "身体状态不错，正常训练即可"
        case .normal: return "身体一般，建议中低强度运动"
        case .tired: return "身体疲劳，建议充分休息或轻度活动"
        case .noData: return "佩戴 Apple Watch 以获取数据"
        }
    }
}

struct DailyStateCard: View {
    let state: BodyState
    let todayHRV: Double?
    let avgHRV: Double?
    let todayRHR: Double?
    let sleepQuality: Double?
    let weekStates: [BodyState]

    var body: some View {
        VStack(spacing: 0) {
            mainStateSection
            if !weekStates.isEmpty {
                Divider().padding(.horizontal, 16)
                weekOverview
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: state.gradient.map { $0.opacity(0.12) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var mainStateSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: state.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: state.color.opacity(0.4), radius: 8, y: 4)

                Image(systemName: state.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: state == .excellent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("今日状态")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(state.color)
                Text(state.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let hrv = todayHRV {
                    miniMetric(icon: "waveform.path.ecg", label: "HRV", value: String(format: "%.0f", hrv), unit: "ms")
                }
                if let rhr = todayRHR {
                    miniMetric(icon: "heart.fill", label: "RHR", value: String(format: "%.0f", rhr), unit: "bpm")
                }
                if let sq = sleepQuality, sq > 0 {
                    miniMetric(icon: "moon.fill", label: "睡眠", value: String(format: "%.0f", sq), unit: "分")
                }
            }
        }
        .padding(16)
    }

    private func miniMetric(icon: String, label: String, value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周状态")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Array(weekStates.enumerated()), id: \.offset) { idx, s in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: s.gradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: s.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            )
                        Text(dayLabel(idx))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    if idx < weekStates.count - 1 { Spacer() }
                }
            }
        }
        .padding(16)
    }

    private func dayLabel(_ idx: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -(weekStates.count - 1 - idx), to: Date())!
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

struct StateEvaluator {
    static func evaluate(todayHRV: Double?, avgHRV: Double?, todayRHR: Double?, avgRHR: Double?, sleepQuality: Double?) -> BodyState {
        guard let todayHRV, let avgHRV, avgHRV > 0 else { return .noData }

        let hrvRatio = todayHRV / avgHRV
        var score = 50.0

        if hrvRatio > 1.15 { score += 30 }
        else if hrvRatio > 1.0 { score += 15 }
        else if hrvRatio > 0.85 { score += 0 }
        else { score -= 20 }

        if let todayRHR, let avgRHR, avgRHR > 0 {
            let rhrRatio = todayRHR / avgRHR
            if rhrRatio < 0.95 { score += 10 }
            else if rhrRatio > 1.05 { score -= 10 }
        }

        if let sq = sleepQuality {
            if sq >= 80 { score += 10 }
            else if sq >= 60 { score += 5 }
            else if sq < 40 { score -= 10 }
        }

        if score >= 75 { return .excellent }
        if score >= 55 { return .good }
        if score >= 35 { return .normal }
        return .tired
    }
}
