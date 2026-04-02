import SwiftUI
import HealthKit

enum AppState: Equatable {
    case onboarding
    case loading
    case dashboard
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.onboarding, .onboarding), (.loading, .loading), (.dashboard, .dashboard):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .onboarding:
                OnboardingView(onComplete: viewModel.onboardingComplete)
                    .transition(.opacity)

            case .loading:
                LoadingView(progress: viewModel.loadingProgress, message: viewModel.loadingMessage)
                    .transition(.opacity)

            case .dashboard:
                if let data = viewModel.dashboardData {
                    NativeDashboardView(data: data, onRefresh: viewModel.refreshData)
                        .transition(.opacity)
                }

            case .error(let message):
                ErrorView(message: message, onRetry: viewModel.refreshData)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.state)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("数据加载失败")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(width: 200, height: 50)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 10)
        }
    }
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var state: AppState = .onboarding
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage: String = "准备中..."
    @Published var dashboardData: DashboardData?

    private let healthKit = HealthKitManager()
    private let hasCompletedOnboarding = "hasCompletedOnboarding"

    init() {
        #if DEBUG && targetEnvironment(simulator)
        // Use mock data in simulator
        dashboardData = MockData.generate()
        state = .dashboard
        UserDefaults.standard.set(true, forKey: hasCompletedOnboarding)
        #else
        if UserDefaults.standard.bool(forKey: hasCompletedOnboarding) {
            state = .loading
            Task { await loadData() }
        }
        #endif
    }

    func onboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboarding)
        state = .loading
        Task { await loadData() }
    }

    func refreshData() {
        #if DEBUG && targetEnvironment(simulator)
        dashboardData = MockData.generate()
        state = .dashboard
        #else
        state = .loading
        loadingProgress = 0
        Task { await loadData() }
        #endif
    }

    private func loadData() async {
        do {
            loadingMessage = "请求健康数据授权..."
            loadingProgress = 0.05
            try await healthKit.requestAuthorization()

            loadingMessage = "正在读取运动记录..."
            loadingProgress = 0.15
            let workouts = try await healthKit.fetchAllWorkouts()

            loadingMessage = "正在读取健康指标..."
            loadingProgress = 0.4
            let records = try await healthKit.fetchAllHealthRecords()

            loadingMessage = "正在读取骑行路线..."
            loadingProgress = 0.6
            let routes = try await healthKit.fetchWorkoutRoutes(for: workouts.filter {
                $0.workoutActivityType == .cycling
            })

            loadingMessage = "正在转换数据..."
            loadingProgress = 0.8
            let nativeData = NativeDataTransformer.transform(workouts: workouts, records: records)

            loadingProgress = 1.0
            loadingMessage = "完成！"
            try await Task.sleep(for: .milliseconds(300))

            dashboardData = nativeData
            state = .dashboard
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
