import Foundation
import HealthKit

enum NativeDataTransformer {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func transform(
        workouts: [HKWorkout],
        records: HealthKitManager.HealthRecords
    ) -> DashboardData {
        let workoutRecords = workouts.compactMap { hkWorkout -> WorkoutRecord? in
            let type = mapWorkoutType(hkWorkout.workoutActivityType)
            let durationMin = hkWorkout.duration / 60.0

            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            var avgHR: Double?
            var maxHR: Double?

            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let stats = hkWorkout.statistics(for: hrType) {
                avgHR = stats.averageQuantity()?.doubleValue(for: hrUnit)
                maxHR = stats.maximumQuantity()?.doubleValue(for: hrUnit)
            }

            var activeCal: Double = 0
            if let aeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let stats = hkWorkout.statistics(for: aeType),
               let sum = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                activeCal = sum
            }

            let distanceKm = extractDistance(workout: hkWorkout, type: type)
            let avgSpeed = distanceKm != nil && durationMin > 0
                ? distanceKm! / (durationMin / 60.0) : nil
            let avgPace = type == .running && distanceKm != nil && distanceKm! > 0
                ? durationMin / distanceKm! : nil

            return WorkoutRecord(
                date: hkWorkout.startDate, type: type,
                durationMin: round(durationMin * 10) / 10,
                activeCal: round(activeCal * 10) / 10,
                avgHR: avgHR.map { round($0 * 10) / 10 },
                maxHR: maxHR.map { round($0 * 10) / 10 },
                distanceKm: distanceKm.map { round($0 * 100) / 100 },
                avgSpeedKmh: avgSpeed.map { round($0 * 10) / 10 },
                avgPaceMinKm: avgPace.map { round($0 * 100) / 100 }
            )
        }

        let health = buildHealthSnapshot(from: records)

        return DashboardData(
            workouts: workoutRecords,
            health: health,
            generatedAt: Date()
        )
    }

    private static func extractDistance(workout: HKWorkout, type: WorkoutType) -> Double? {
        let typeMap: [(HKQuantityTypeIdentifier, Set<WorkoutType>)] = [
            (.distanceCycling, [.cycling]),
            (.distanceWalkingRunning, [.running, .walking, .hiking]),
            (.distanceSwimming, [.swimming]),
        ]

        for (typeId, types) in typeMap {
            if types.contains(type),
               let qt = HKQuantityType.quantityType(forIdentifier: typeId),
               let stats = workout.statistics(for: qt),
               let sum = stats.sumQuantity()?.doubleValue(for: .meter()), sum > 0 {
                return sum / 1000.0
            }
        }
        return nil
    }

    private static func buildHealthSnapshot(from records: HealthKitManager.HealthRecords) -> HealthSnapshot {
        func toDailyMetrics(_ dict: [String: Double]?) -> [DailyMetric] {
            guard let dict else { return [] }
            return dict.compactMap { (dateStr, value) -> DailyMetric? in
                guard let date = dateFormatter.date(from: dateStr) else { return nil }
                return DailyMetric(date: date, value: value)
            }.sorted { $0.date < $1.date }
        }

        return HealthSnapshot(
            restingHR: toDailyMetrics(records.dailyData["resting_hr"]),
            hrv: toDailyMetrics(records.dailyData["hrv"]),
            vo2max: toDailyMetrics(records.dailyData["vo2max"]),
            bodyMass: toDailyMetrics(records.dailyData["body_mass"]),
            steps: toDailyMetrics(records.dailyData["steps"]),
            activeEnergy: toDailyMetrics(records.dailyData["active_energy"])
        )
    }

    private static func mapWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutType {
        switch hkType {
        case .cycling: return .cycling
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        case .running: return .running
        case .walking: return .walking
        case .swimming: return .swimming
        case .highIntensityIntervalTraining: return .hiit
        case .yoga: return .yoga
        case .hiking: return .hiking
        default: return .other
        }
    }
}
