import Foundation

#if DEBUG
enum MockData {
    static func generate() -> DashboardData {
        let cal = Calendar.current
        let now = Date()

        var workouts: [WorkoutRecord] = []

        // 90 days of mock workouts
        for dayOffset in 0..<90 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let wd = cal.component(.weekday, from: date)

            // Cycling 3x/week
            if [2, 4, 6].contains(wd) {
                let dist = Double.random(in: 8...25)
                let dur = dist / Double.random(in: 18...26) * 60
                workouts.append(WorkoutRecord(
                    date: date, type: .cycling, durationMin: dur,
                    activeCal: dur * 7.5, avgHR: Double.random(in: 130...160),
                    maxHR: Double.random(in: 165...185), distanceKm: dist,
                    avgSpeedKmh: dist / (dur / 60), avgPaceMinKm: nil
                ))
            }

            // Strength 3x/week
            if [2, 3, 5].contains(wd) {
                let dur = Double.random(in: 40...70)
                workouts.append(WorkoutRecord(
                    date: date, type: .strength, durationMin: dur,
                    activeCal: dur * 6, avgHR: Double.random(in: 100...135),
                    maxHR: Double.random(in: 145...170), distanceKm: nil,
                    avgSpeedKmh: nil, avgPaceMinKm: nil
                ))
            }

            // Running 2x/week
            if [3, 7].contains(wd) {
                let dist = Double.random(in: 3...8)
                let pace = Double.random(in: 5.0...6.5)
                let dur = dist * pace
                workouts.append(WorkoutRecord(
                    date: date, type: .running, durationMin: dur,
                    activeCal: dur * 9, avgHR: Double.random(in: 145...175),
                    maxHR: Double.random(in: 175...195), distanceKm: dist,
                    avgSpeedKmh: 60 / pace, avgPaceMinKm: pace
                ))
            }

            // Occasional yoga
            if wd == 1 && dayOffset % 14 < 7 {
                workouts.append(WorkoutRecord(
                    date: date, type: .yoga, durationMin: Double.random(in: 30...60),
                    activeCal: Double.random(in: 80...150), avgHR: Double.random(in: 70...90),
                    maxHR: Double.random(in: 95...115), distanceKm: nil,
                    avgSpeedKmh: nil, avgPaceMinKm: nil
                ))
            }
        }

        // Health metrics
        var rhr: [DailyMetric] = []
        var hrv: [DailyMetric] = []
        var vo2: [DailyMetric] = []
        var mass: [DailyMetric] = []
        var steps: [DailyMetric] = []
        var energy: [DailyMetric] = []

        for dayOffset in 0..<90 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let progress = Double(90 - dayOffset) / 90.0

            rhr.append(DailyMetric(date: date, value: 62 - progress * 4 + .random(in: -2...2)))
            hrv.append(DailyMetric(date: date, value: 38 + progress * 12 + .random(in: -5...5)))
            steps.append(DailyMetric(date: date, value: Double.random(in: 5000...13000)))
            energy.append(DailyMetric(date: date, value: Double.random(in: 300...800)))

            if dayOffset % 3 == 0 {
                vo2.append(DailyMetric(date: date, value: 42 + progress * 4 + .random(in: -1...1)))
            }
            if dayOffset % 7 == 0 {
                mass.append(DailyMetric(date: date, value: 72 - progress * 2 + .random(in: -0.3...0.3)))
            }
        }

        let health = HealthSnapshot(
            restingHR: rhr.reversed(), hrv: hrv.reversed(),
            vo2max: vo2.reversed(), bodyMass: mass.reversed(),
            steps: steps.reversed(), activeEnergy: energy.reversed()
        )

        return DashboardData(workouts: workouts, health: health, generatedAt: now)
    }
}
#endif
