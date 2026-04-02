import SwiftUI

enum AppState {
    case onboarding
    case loading
    case dashboard(String) // JSON data string
    case error(String)
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

            case .dashboard(let json):
                DashboardWebView(jsonData: json, onRefresh: viewModel.refreshData)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.opacity)

            case .error(let message):
                ErrorView(message: message, onRetry: viewModel.refreshData)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.stateKey)
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

    private let healthKit = HealthKitManager()
    private let hasCompletedOnboarding = "hasCompletedOnboarding"

    var stateKey: String {
        switch state {
        case .onboarding: return "onboarding"
        case .loading: return "loading"
        case .dashboard: return "dashboard"
        case .error: return "error"
        }
    }

    init() {
        if UserDefaults.standard.bool(forKey: hasCompletedOnboarding) {
            state = .loading
            Task { await loadData() }
        }
    }

    func onboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboarding)
        state = .loading
        Task { await loadData() }
    }

    func refreshData() {
        state = .loading
        loadingProgress = 0
        Task { await loadData() }
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

            loadingMessage = "正在生成分析报告..."
            loadingProgress = 0.8
            let transformer = DataTransformer()
            let json = try transformer.transform(workouts: workouts, records: records, routes: routes)

            loadingProgress = 1.0
            loadingMessage = "完成！"
            try await Task.sleep(for: .milliseconds(300))

            state = .dashboard(json)

            if let cacheURL = cacheURL {
                try? json.write(to: cacheURL, atomically: true, encoding: .utf8)
            }
        } catch {
            if let cached = loadCachedData() {
                state = .dashboard(cached)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("health_data.json")
    }

    private func loadCachedData() -> String? {
        guard let url = cacheURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
