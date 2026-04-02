import Foundation
import UserNotifications
import HealthKit

final class StateNotificationManager {
    static let shared = StateNotificationManager()

    private let store = HKHealthStore()
    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification auth error: \(error)")
            return false
        }
    }

    // MARK: - Schedule Daily Reminders

    func scheduleDailyReminders(enabled: Bool) {
        notificationCenter.removeAllPendingNotificationRequests()

        guard enabled else { return }

        let reminders: [(hour: Int, minute: Int, id: String, title: String)] = [
            (9, 0, "morning-state", "🌅 早间状态"),
            (12, 30, "noon-state", "☀️ 午间状态"),
            (17, 0, "afternoon-state", "🌇 下午状态"),
        ]

        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = "点击查看你的身体状态评估"
            content.sound = .default
            content.categoryIdentifier = "STATE_CHECK"

            var dateComponents = DateComponents()
            dateComponents.hour = r.hour
            dateComponents.minute = r.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: r.id, content: content, trigger: trigger)

            notificationCenter.add(request) { error in
                if let error {
                    print("Failed to schedule \(r.id): \(error)")
                }
            }
        }
    }

    // MARK: - HRV Background Delivery

    func enableHRVBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        store.enableBackgroundDelivery(for: hrvType, frequency: .hourly) { success, error in
            if let error {
                print("HRV background delivery error: \(error)")
            } else if success {
                print("HRV background delivery enabled")
            }
        }
    }

    // MARK: - Evaluate and Notify

    func evaluateAndNotify() async {
        let state = await fetchCurrentState()
        await sendStateNotification(state: state)
    }

    private func fetchCurrentState() async -> BodyState {
        guard HKHealthStore.isHealthDataAvailable() else { return .noData }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let today = Calendar.current.startOfDay(for: Date())

        async let todayHRV = fetchLatestValue(typeId: .heartRateVariabilitySDNN, from: today)
        async let avgHRV = fetchAvgValue(typeId: .heartRateVariabilitySDNN, from: thirtyDaysAgo)
        async let todayRHR = fetchLatestValue(typeId: .restingHeartRate, from: today)
        async let avgRHR = fetchAvgValue(typeId: .restingHeartRate, from: thirtyDaysAgo)

        let (tHRV, aHRV, tRHR, aRHR) = await (todayHRV, avgHRV, todayRHR, avgRHR)

        return StateEvaluator.evaluate(
            todayHRV: tHRV, avgHRV: aHRV,
            todayRHR: tRHR, avgRHR: aRHR,
            sleepQuality: nil
        )
    }

    private func fetchLatestValue(typeId: HKQuantityTypeIdentifier, from start: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeId) else { return nil }
        let unit = preferredUnit(for: typeId)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let val = (results?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: val)
            }
            store.execute(query)
        }
    }

    private func fetchAvgValue(typeId: HKQuantityTypeIdentifier, from start: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeId) else { return nil }
        let unit = preferredUnit(for: typeId)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func preferredUnit(for id: HKQuantityTypeIdentifier) -> HKUnit {
        switch id {
        case .heartRateVariabilitySDNN: return .secondUnit(with: .milli)
        case .restingHeartRate: return .count().unitDivided(by: .minute())
        default: return .count()
        }
    }

    @MainActor
    private func sendStateNotification(state: BodyState) async {
        guard state != .noData else { return }

        let content = UNMutableNotificationContent()
        content.title = stateNotificationTitle(state)
        content.body = state.advice
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "state-update-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Send notification error: \(error)")
        }
    }

    private func stateNotificationTitle(_ state: BodyState) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeEmoji: String
        if hour < 12 { timeEmoji = "🌅" }
        else if hour < 17 { timeEmoji = "☀️" }
        else { timeEmoji = "🌇" }

        switch state {
        case .excellent: return "\(timeEmoji) \(state.rawValue) ✨ 今天适合挑战自己！"
        case .good: return "\(timeEmoji) \(state.rawValue) 💪 保持节奏，继续前行"
        case .normal: return "\(timeEmoji) \(state.rawValue) 🧘 适度活动即可"
        case .tired: return "\(timeEmoji) \(state.rawValue) 😴 给身体充充电"
        case .noData: return ""
        }
    }
}
