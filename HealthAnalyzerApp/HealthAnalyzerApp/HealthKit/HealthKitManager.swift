import HealthKit
import CoreLocation

final class HealthKitManager {
    private let store = HKHealthStore()

    private static let quantityTypes: [(HKQuantityTypeIdentifier, String)] = [
        (.restingHeartRate, "resting_hr"),
        (.heartRateVariabilitySDNN, "hrv"),
        (.vo2Max, "vo2max"),
        (.bodyMass, "body_mass"),
        (.stepCount, "steps"),
        (.activeEnergyBurned, "active_energy"),
        (.walkingHeartRateAverage, "walking_hr"),
        (.heartRateRecoveryOneMinute, "hr_recovery"),
        (.oxygenSaturation, "spo2"),
        (.dietaryProtein, "protein"),
        (.dietaryEnergyConsumed, "dietary_energy"),
        (.appleExerciseTime, "exercise_time"),
        // Mobility & gait
        (.walkingAsymmetryPercentage, "walk_asymmetry"),
        (.walkingDoubleSupportPercentage, "walk_double_support"),
        (.walkingSpeed, "walk_speed"),
        (.walkingStepLength, "walk_step_length"),
        // Respiratory
        (.respiratoryRate, "respiratory_rate"),
        // Body composition
        (.bodyFatPercentage, "body_fat"),
        (.bodyMassIndex, "bmi"),
        // Activity
        (.appleStandTime, "stand_time"),
        (.distanceWalkingRunning, "walk_run_distance"),
    ]

    private static let sumKeys: Set<String> = [
        "steps", "active_energy", "protein", "dietary_energy", "exercise_time",
        "stand_time", "walk_run_distance"
    ]

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        var readTypes = Set<HKObjectType>()

        for (id, _) in Self.quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                readTypes.insert(t)
            }
        }

        readTypes.insert(HKObjectType.workoutType())
        readTypes.insert(HKSeriesType.workoutRoute())

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(hrType)
        }

        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Fetch All Workouts

    func fetchAllWorkouts() async throws -> [HKWorkout] {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let predicate = HKQuery.predicateForSamples(
            withStart: twoYearsAgo,
            end: Date(),
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Fetch Health Records

    struct HealthRecords {
        var dailyData: [String: [String: Double]] = [:]  // key -> { date: value }
    }

    func fetchAllHealthRecords() async throws -> HealthRecords {
        var records = HealthRecords()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        try await withThrowingTaskGroup(of: (String, [String: Double]).self) { group in
            for (typeId, key) in Self.quantityTypes {
                guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeId) else { continue }

                group.addTask { [store] in
                    let unit = Self.preferredUnit(for: typeId)
                    let isSumType = Self.sumKeys.contains(key)

                    let dailyValues = try await Self.fetchDailyAggregates(
                        store: store,
                        type: quantityType,
                        unit: unit,
                        startDate: twoYearsAgo,
                        isSum: isSumType
                    )
                    return (key, dailyValues)
                }
            }

            for try await (key, values) in group {
                records.dailyData[key] = values
            }
        }

        return records
    }

    // MARK: - Fetch Workout Routes (for cycling)

    struct WorkoutRoute {
        let workoutUUID: UUID
        let locations: [CLLocation]
    }

    func fetchWorkoutRoutes(for workouts: [HKWorkout]) async throws -> [WorkoutRoute] {
        var routes: [WorkoutRoute] = []

        for workout in workouts {
            if let route = try await fetchRoute(for: workout) {
                routes.append(WorkoutRoute(workoutUUID: workout.uuid, locations: route))
            }
        }

        return routes
    }

    private func fetchRoute(for workout: HKWorkout) async throws -> [CLLocation]? {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routeSamples: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        guard let routeSample = routeSamples.first else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            var allLocations: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: routeSample) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let locations { allLocations.append(contentsOf: locations) }
                if done { continuation.resume(returning: allLocations) }
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    struct SleepRecord: Identifiable {
        let id = UUID()
        let date: Date
        var inBedMin: Double = 0
        var asleepMin: Double = 0
        var deepMin: Double = 0
        var remMin: Double = 0
        var coreMin: Double = 0
        var awakeMin: Double = 0
    }

    func fetchSleepData() async throws -> [SleepRecord] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: twoYearsAgo, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                       limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        var byDate: [String: SleepRecord] = [:]

        for sample in samples {
            let sleepDate = cal.startOfDay(for: sample.startDate)
            let key = df.string(from: sleepDate)
            let dur = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

            if byDate[key] == nil {
                byDate[key] = SleepRecord(date: sleepDate)
            }

            let val = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            switch val {
            case .inBed:
                byDate[key]!.inBedMin += dur
            case .asleepUnspecified, .asleep:
                byDate[key]!.asleepMin += dur
            case .asleepDeep:
                byDate[key]!.deepMin += dur
            case .asleepREM:
                byDate[key]!.remMin += dur
            case .asleepCore:
                byDate[key]!.coreMin += dur
            case .awake:
                byDate[key]!.awakeMin += dur
            default:
                break
            }
        }

        return byDate.values.sorted { $0.date < $1.date }
    }

    // MARK: - Helpers

    private static func preferredUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .restingHeartRate, .walkingHeartRateAverage, .heartRateRecoveryOneMinute:
            return .count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        case .respiratoryRate:
            return .count().unitDivided(by: .minute())
        case .vo2Max:
            return HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case .bodyMass, .leanBodyMass:
            return .gramUnit(with: .kilo)
        case .stepCount:
            return .count()
        case .activeEnergyBurned, .dietaryEnergyConsumed:
            return .kilocalorie()
        case .oxygenSaturation, .bodyFatPercentage, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage:
            return .percent()
        case .dietaryProtein:
            return .gram()
        case .appleExerciseTime, .appleStandTime:
            return .minute()
        case .walkingSpeed:
            return HKUnit.meter().unitDivided(by: .second())
        case .walkingStepLength:
            return .meter()
        case .bodyMassIndex:
            return .count()
        case .distanceWalkingRunning:
            return .meter()
        default:
            return .count()
        }
    }

    private static func fetchDailyAggregates(
        store: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit,
        startDate: Date,
        isSum: Bool
    ) async throws -> [String: Double] {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)

        let statisticsOptions: HKStatisticsOptions = isSum
            ? .cumulativeSum
            : .discreteAverage

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: Date(),
                    options: .strictStartDate
                ),
                options: statisticsOptions,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }

                var results: [String: Double] = [:]
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone.current

                collection?.enumerateStatistics(from: startDate, to: Date()) { stats, _ in
                    let value: Double?
                    if isSum {
                        value = stats.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        value = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let v = value {
                        let dateStr = formatter.string(from: stats.startDate)
                        results[dateStr] = (v * 10).rounded() / 10
                    }
                }

                continuation.resume(returning: results)
            }

            store.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "此设备不支持 HealthKit"
        case .queryFailed(let msg):
            return "数据查询失败: \(msg)"
        }
    }
}
