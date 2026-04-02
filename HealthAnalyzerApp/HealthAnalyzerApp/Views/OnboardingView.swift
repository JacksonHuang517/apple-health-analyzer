import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.text.clipboard.fill",
            iconColor: .red,
            title: "健康数据分析",
            subtitle: "深入了解你的运动表现与身体变化趋势",
            description: "分析骑行、力量训练、跑步等运动数据，结合心率、VO2 Max、HRV 等指标，全方位掌握健康状态。"
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            iconColor: .blue,
            title: "智能图表可视化",
            subtitle: "交互式仪表盘，数据一目了然",
            description: "多维度图表展示运动趋势、跨运动关联分析、身体指标变化。支持按时间范围筛选，自由探索数据。"
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            iconColor: .green,
            title: "隐私优先",
            subtitle: "数据仅在你的设备上处理",
            description: "所有健康数据分析均在本地完成，不会上传到任何服务器。我们需要你的授权来读取 Apple Health 数据。"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomSection
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(page.iconColor)
            }

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title.bold())

                Text(page.subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(page.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
    }

    @ViewBuilder
    private var bottomSection: some View {
        if currentPage < pages.count - 1 {
            Button {
                withAnimation { currentPage += 1 }
            } label: {
                Text("继续")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        } else {
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("授权并开始分析")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}
