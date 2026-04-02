import Foundation
import SwiftUI

// MARK: - Workout

struct WorkoutRecord: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let type: WorkoutType
    let durationMin: Double
    let activeCal: Double
    let avgHR: Double?
    let maxHR: Double?
    let distanceKm: Double?
    let avgSpeedKmh: Double?
    let avgPaceMinKm: Double?

    var weekday: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

enum WorkoutType: String, CaseIterable, Identifiable {
    case cycling = "骑行"
    case strength = "力量训练"
    case running = "跑步"
    case walking = "步行"
    case swimming = "游泳"
    case hiit = "HIIT"
    case yoga = "瑜伽"
    case hiking = "徒步"
    case other = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cycling: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .hiit: return "flame.fill"
        case .yoga: return "figure.yoga"
        case .hiking: return "figure.hiking"
        case .other: return "figure.mixed.cardio"
        }
    }

    var color: Color {
        switch self {
        case .cycling: return .green
        case .strength: return .orange
        case .running: return .blue
        case .walking: return .teal
        case .swimming: return .cyan
        case .hiit: return .red
        case .yoga: return .purple
        case .hiking: return .brown
        case .other: return .gray
        }
    }
}

// MARK: - Health Metrics

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double

    var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

struct SleepDay: Identifiable {
    let id = UUID()
    let date: Date
    var totalMin: Double
    var deepMin: Double
    var remMin: Double
    var coreMin: Double
    var awakeMin: Double

    var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: date)
    }

    var qualityScore: Double {
        guard totalMin > 0 else { return 0 }
        let deepRatio = deepMin / totalMin
        let remRatio = remMin / totalMin
        let awakeRatio = awakeMin / max(totalMin, 1)
        var score = 50.0
        score += deepRatio * 150
        score += remRatio * 100
        score -= awakeRatio * 80
        if totalMin >= 420 && totalMin <= 540 { score += 15 }
        return min(max(score, 0), 100)
    }
}

struct HealthSnapshot {
    var restingHR: [DailyMetric] = []
    var hrv: [DailyMetric] = []
    var vo2max: [DailyMetric] = []
    var bodyMass: [DailyMetric] = []
    var steps: [DailyMetric] = []
    var activeEnergy: [DailyMetric] = []
    // Mobility
    var walkAsymmetry: [DailyMetric] = []
    var walkDoubleSupport: [DailyMetric] = []
    var walkSpeed: [DailyMetric] = []
    var walkStepLength: [DailyMetric] = []
    // Respiratory
    var respiratoryRate: [DailyMetric] = []
    // Body composition
    var bodyFat: [DailyMetric] = []
    var bmi: [DailyMetric] = []
    // Activity
    var standTime: [DailyMetric] = []
    var walkRunDistance: [DailyMetric] = []
    // Sleep
    var sleep: [SleepDay] = []

    var latestRestingHR: Double? { restingHR.last?.value }
    var latestHRV: Double? { hrv.last?.value }
    var latestVO2Max: Double? { vo2max.last?.value }
    var latestWeight: Double? { bodyMass.last?.value }
    var avgSteps: Double? {
        guard !steps.isEmpty else { return nil }
        return steps.map(\.value).reduce(0, +) / Double(steps.count)
    }
    var latestBodyFat: Double? { bodyFat.last?.value }
    var latestBMI: Double? { bmi.last?.value }
    var avgSleepMin: Double? {
        guard !sleep.isEmpty else { return nil }
        return sleep.map(\.totalMin).reduce(0, +) / Double(sleep.count)
    }
    var avgSleepQuality: Double? {
        guard !sleep.isEmpty else { return nil }
        return sleep.map(\.qualityScore).reduce(0, +) / Double(sleep.count)
    }
}

// MARK: - Period Filter

enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "1周"
    case month = "1月"
    case threeMonths = "3月"
    case sixMonths = "半年"
    case year = "1年"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }
}

// MARK: - Dashboard Data

struct DashboardData {
    let workouts: [WorkoutRecord]
    let health: HealthSnapshot
    let generatedAt: Date

    var workoutTypes: [WorkoutType] {
        let types = Set(workouts.map(\.type))
        return WorkoutType.allCases.filter { types.contains($0) }
    }

    func workouts(for type: WorkoutType, in period: TimePeriod) -> [WorkoutRecord] {
        let start = period.startDate
        return workouts.filter { $0.type == type && $0.date >= start }
    }

    func allWorkouts(in period: TimePeriod) -> [WorkoutRecord] {
        let start = period.startDate
        return workouts.filter { $0.date >= start }
    }

    func totalDuration(for type: WorkoutType, in period: TimePeriod) -> Double {
        workouts(for: type, in: period).map(\.durationMin).reduce(0, +)
    }

    func totalCalories(in period: TimePeriod) -> Double {
        allWorkouts(in: period).map(\.activeCal).reduce(0, +)
    }

    func sessionCount(in period: TimePeriod) -> Int {
        allWorkouts(in: period).count
    }

    func metrics(_ keyPath: KeyPath<HealthSnapshot, [DailyMetric]>, in period: TimePeriod) -> [DailyMetric] {
        let start = period.startDate
        return health[keyPath: keyPath].filter { $0.date >= start }
    }

    func sleepData(in period: TimePeriod) -> [SleepDay] {
        let start = period.startDate
        return health.sleep.filter { $0.date >= start }
    }
}
