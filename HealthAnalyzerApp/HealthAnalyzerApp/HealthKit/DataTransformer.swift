import Foundation
import HealthKit
import CoreLocation

struct DataTransformer {
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // Map HKWorkoutActivityType to our internal keys (matching Python WORKOUT_KEYS)
    private static let workoutKeyMap: [HKWorkoutActivityType: (key: String, label: String)] = [
        .cycling: ("cycling", "骑行"),
        .traditionalStrengthTraining: ("strength", "力量训练"),
        .functionalStrengthTraining: ("strength", "力量训练"),
        .running: ("running", "跑步"),
        .walking: ("walking", "步行"),
        .swimming: ("swimming", "游泳"),
        .highIntensityIntervalTraining: ("hiit", "HIIT"),
        .climbing: ("climbing", "攀岩"),
        .hiking: ("hiking", "徒步"),
        .badminton: ("badminton", "羽毛球"),
        .coreTraining: ("core", "核心训练"),
        .elliptical: ("elliptical", "椭圆机"),
        .stairClimbing: ("stairs", "爬楼"),
        .yoga: ("yoga", "瑜伽"),
        .pilates: ("pilates", "普拉提"),
        .tableTennis: ("tabletennis", "乒乓球"),
        .tennis: ("tennis", "网球"),
        .rowing: ("rowing", "划船"),
        .socialDance: ("dance", "舞蹈"),
        .soccer: ("soccer", "足球"),
        .basketball: ("basketball", "篮球"),
        .mixedCardio: ("mixedcardio", "混合有氧"),
        .jumpRope: ("jumprope", "跳绳"),
        .skatingSports: ("skating", "滑冰"),
        .snowSports: ("snow", "雪上运动"),
        .surfingSports: ("surfing", "冲浪"),
        .martialArts: ("martialarts", "武术"),
        .boxing: ("boxing", "拳击"),
        .kickboxing: ("kickboxing", "搏击"),
    ]

    private static let dedicatedKeys: Set<String> = ["cycling", "strength", "running"]

    // MARK: - Transform

    func transform(
        workouts: [HKWorkout],
        records: HealthKitManager.HealthRecords,
        routes: [HealthKitManager.WorkoutRoute]
    ) throws -> String {
        let routeMap = Dictionary(uniqueKeysWithValues: routes.map { ($0.workoutUUID, $0.locations) })

        // Group workouts by key
        var grouped: [String: [[String: Any]]] = [:]
        for workout in workouts {
            let (key, _) = resolveWorkoutKey(workout.workoutActivityType)
            let item = buildWorkoutItem(workout: workout, key: key, routeLocations: routeMap[workout.uuid])
            grouped[key, default: []].append(item)
        }

        // Build workout_types summary
        var workoutTypes: [[String: Any]] = []
        let allKeys = grouped.keys.sorted { a, b in
            let aCount = grouped[a]?.count ?? 0
            let bCount = grouped[b]?.count ?? 0
            return aCount > bCount
        }

        for key in allKeys {
            guard let items = grouped[key], !items.isEmpty else { continue }
            let (_, label) = resolveWorkoutKey(for: key)
            let totalDur = items.compactMap { $0["duration_min"] as? Double }.reduce(0, +)
            let hasHr = items.contains { ($0["avg_hr"] as? Double) != nil && ($0["avg_hr"] as? Double ?? 0) > 0 }
            let hasDist = items.contains { ($0["distance_km"] as? Double) != nil && ($0["distance_km"] as? Double ?? 0) > 0 }
            let hasSpeed = items.contains { ($0["avg_speed_kmh"] as? Double) != nil && ($0["avg_speed_kmh"] as? Double ?? 0) > 0 }

            workoutTypes.append([
                "key": key,
                "label": label,
                "count": items.count,
                "total_duration_min": round(totalDur * 10) / 10,
                "has_distance": hasDist,
                "has_hr": hasHr,
                "has_speed": hasSpeed,
                "dedicated": Self.dedicatedKeys.contains(key),
            ])
        }

        // Route clustering for cycling
        let cyclingItems = grouped["cycling"] ?? []
        let (clusters, commuteId) = computeRouteClusters(cyclingItems: cyclingItems)

        // Assign route_cluster to cycling items
        if commuteId >= 0 {
            grouped["cycling"] = cyclingItems.map { item in
                var m = item
                if let slat = item["start_lat"] as? Double,
                   let slon = item["start_lon"] as? Double,
                   let elat = item["end_lat"] as? Double,
                   let elon = item["end_lon"] as? Double {
                    for cluster in clusters {
                        if let cslat = cluster["start_lat"] as? Double,
                           let cslon = cluster["start_lon"] as? Double,
                           let celat = cluster["end_lat"] as? Double,
                           let celon = cluster["end_lon"] as? Double {
                            if haversine(slat, slon, cslat, cslon) < 800 &&
                               haversine(elat, elon, celat, celon) < 800 {
                                m["route_cluster"] = cluster["id"]
                                break
                            }
                        }
                    }
                }
                // Strip coordinates from output
                m.removeValue(forKey: "start_lat")
                m.removeValue(forKey: "start_lon")
                m.removeValue(forKey: "end_lat")
                m.removeValue(forKey: "end_lon")
                return m
            }
        }

        // Strip coordinates from cluster output
        let strippedClusters: [[String: Any]] = clusters.map {
            var c = $0
            c.removeValue(forKey: "start_lat")
            c.removeValue(forKey: "start_lon")
            c.removeValue(forKey: "end_lat")
            c.removeValue(forKey: "end_lon")
            return c
        }

        // Build other (non-cycling, non-strength)
        let otherItems = grouped.filter { !Self.dedicatedKeys.contains($0.key) }.flatMap { $0.value }

        // Build the final DATA object
        var data: [String: Any] = [
            "generated_at": isoFormatter.string(from: Date()),
            "workout_types": workoutTypes,
            "workouts": grouped,
            "cycling": grouped["cycling"] ?? [],
            "strength": grouped["strength"] ?? [],
            "other": otherItems,
            "route_clusters": strippedClusters,
            "commute_cluster_id": commuteId,
        ]

        // Add daily health records
        for (key, values) in records.dailyData {
            data[key] = values
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw TransformError.serializationFailed
        }
        return jsonString
    }

    // MARK: - Build Workout Item

    private func buildWorkoutItem(
        workout: HKWorkout,
        key: String,
        routeLocations: [CLLocation]?
    ) -> [String: Any] {
        let date = dateFormatter.string(from: workout.startDate)
        let durationMin = workout.duration / 60.0
        let weekday = Calendar.current.component(.weekday, from: workout.startDate)
        let startHour = Calendar.current.component(.hour, from: workout.startDate)

        var item: [String: Any] = [
            "date": date,
            "key": key,
            "duration_min": round(durationMin * 10) / 10,
            "weekday": weekday,
            "start_hour": startHour,
        ]

        // Heart rate stats
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            if let stats = workout.statistics(for: hrType) {
                if let avg = stats.averageQuantity()?.doubleValue(for: hrUnit) {
                    item["avg_hr"] = round(avg * 10) / 10
                }
                if let max = stats.maximumQuantity()?.doubleValue(for: hrUnit) {
                    item["max_hr"] = round(max * 10) / 10
                }
                if let min = stats.minimumQuantity()?.doubleValue(for: hrUnit) {
                    item["min_hr"] = round(min * 10) / 10
                }
            }
        }

        // Active energy
        if let aeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            if let stats = workout.statistics(for: aeType),
               let sum = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                item["active_cal"] = round(sum * 10) / 10
            }
        }

        // Distance
        let distanceKm = extractDistance(workout: workout, key: key)
        if distanceKm > 0 {
            item["distance_km"] = round(distanceKm * 100) / 100
            if durationMin > 0 {
                let speedKmh = distanceKm / (durationMin / 60.0)
                item["avg_speed_kmh"] = round(speedKmh * 10) / 10
            }
        }

        // Running pace
        if key == "running" && distanceKm > 0 && durationMin > 0 {
            let paceMinKm = durationMin / distanceKm
            item["avg_pace_min_km"] = round(paceMinKm * 100) / 100
            item["avg_speed_kmh"] = round((distanceKm / (durationMin / 60.0)) * 10) / 10
        }

        // Route data for cycling
        if key == "cycling", let locations = routeLocations, locations.count > 1 {
            let speeds = locations.compactMap { $0.speed > 0.5 ? $0.speed : nil }
            if !speeds.isEmpty {
                let avgSpeedMs = speeds.reduce(0, +) / Double(speeds.count)
                item["gpx_avg_speed_kmh"] = round(avgSpeedMs * 3.6 * 10) / 10
            }
            item["start_lat"] = locations.first!.coordinate.latitude
            item["start_lon"] = locations.first!.coordinate.longitude
            item["end_lat"] = locations.last!.coordinate.latitude
            item["end_lon"] = locations.last!.coordinate.longitude
        }

        return item
    }

    private func extractDistance(workout: HKWorkout, key: String) -> Double {
        let distTypes: [(HKQuantityTypeIdentifier, Set<String>)] = [
            (.distanceCycling, ["cycling"]),
            (.distanceWalkingRunning, ["running", "walking", "hiking"]),
            (.distanceSwimming, ["swimming"]),
        ]

        for (typeId, keys) in distTypes {
            if keys.contains(key),
               let quantityType = HKQuantityType.quantityType(forIdentifier: typeId),
               let stats = workout.statistics(for: quantityType),
               let sum = stats.sumQuantity()?.doubleValue(for: .meter()) {
                return sum / 1000.0
            }
        }

        // Fallback: try walking/running distance for other types
        if let quantityType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let stats = workout.statistics(for: quantityType),
           let sum = stats.sumQuantity()?.doubleValue(for: .meter()), sum > 0 {
            return sum / 1000.0
        }

        return 0
    }

    // MARK: - Route Clustering (Haversine, 800m threshold)

    private func computeRouteClusters(cyclingItems: [[String: Any]]) -> ([[String: Any]], Int) {
        let withCoords = cyclingItems.filter {
            $0["start_lat"] != nil && $0["end_lat"] != nil
        }
        guard withCoords.count >= 3 else { return ([], -1) }

        // Simple clustering: find the most common start-end pair within 800m
        var clusterGroups: [[[String: Any]]] = []

        for item in withCoords {
            guard let slat = item["start_lat"] as? Double,
                  let slon = item["start_lon"] as? Double,
                  let elat = item["end_lat"] as? Double,
                  let elon = item["end_lon"] as? Double else { continue }

            var matched = false
            for i in 0..<clusterGroups.count {
                let rep = clusterGroups[i][0]
                if let rslat = rep["start_lat"] as? Double,
                   let rslon = rep["start_lon"] as? Double,
                   let relat = rep["end_lat"] as? Double,
                   let relon = rep["end_lon"] as? Double {
                    if haversine(slat, slon, rslat, rslon) < 800 &&
                       haversine(elat, elon, relat, relon) < 800 {
                        clusterGroups[i].append(item)
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                clusterGroups.append([item])
            }
        }

        clusterGroups.sort { $0.count > $1.count }
        let top = Array(clusterGroups.prefix(10))

        var clusters: [[String: Any]] = []
        for (i, group) in top.enumerated() {
            let rep = group[0]
            let dates = group.compactMap { $0["date"] as? String }
            clusters.append([
                "id": i,
                "count": group.count,
                "dates": dates,
                "start_lat": rep["start_lat"] as Any,
                "start_lon": rep["start_lon"] as Any,
                "end_lat": rep["end_lat"] as Any,
                "end_lon": rep["end_lon"] as Any,
            ])
        }

        let commuteId = clusters.isEmpty ? -1 : 0
        return (clusters, commuteId)
    }

    private func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let R = 6371000.0
        let p = Double.pi / 180.0
        let a = 0.5 - cos((lat2 - lat1) * p) / 2.0 +
            cos(lat1 * p) * cos(lat2 * p) * (1.0 - cos((lon2 - lon1) * p)) / 2.0
        return 2.0 * R * asin(sqrt(a))
    }

    private func resolveWorkoutKey(_ activityType: HKWorkoutActivityType) -> (key: String, label: String) {
        if let mapped = Self.workoutKeyMap[activityType] {
            return mapped
        }
        return ("other", "其他")
    }

    private func resolveWorkoutKey(for key: String) -> (key: String, label: String) {
        for (_, mapped) in Self.workoutKeyMap {
            if mapped.key == key { return mapped }
        }
        return (key, key)
    }
}

enum TransformError: LocalizedError {
    case serializationFailed

    var errorDescription: String? {
        "数据序列化失败"
    }
}
