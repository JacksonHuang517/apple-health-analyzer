import SwiftUI

struct NativeDashboardView: View {
    let data: DashboardData
    var onRefresh: (() -> Void)?

    @State private var selectedTab = 0
    @State private var period: TimePeriod = .threeMonths
    @State private var selectedType: WorkoutType?
    @Namespace private var tabAnimation

    private var tabs: [TabItem] {
        var items: [TabItem] = [
            TabItem(title: "概览", icon: "square.grid.2x2.fill", color: .accentColor),
            TabItem(title: "身体", icon: "heart.text.clipboard.fill", color: .red),
        ]
        for type in data.workoutTypes {
            items.append(TabItem(title: type.rawValue, icon: type.icon, color: type.color))
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker
                tabSelector
                Divider().opacity(0.3)
                tabContent
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        Text("健康分析")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let onRefresh {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases) { p in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { period = p }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if period == p {
                                Capsule().fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "period", in: tabAnimation)
                            } else {
                                Capsule().fill(Color(.tertiarySystemFill))
                            }
                        }
                        .foregroundStyle(period == p ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = i
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tabs[i].icon)
                                    .font(.system(size: 12, weight: .medium))
                                Text(tabs[i].title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedTab == i ? tabs[i].color.opacity(0.12) : Color.clear)
                            )
                            .foregroundStyle(selectedTab == i ? tabs[i].color : .secondary)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: selectedTab) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            SummaryTab(data: data, period: $period, selectedType: $selectedType)
                .tag(0)
            BodyTab(data: data, period: $period)
                .tag(1)
            ForEach(Array(data.workoutTypes.enumerated()), id: \.offset) { offset, type in
                WorkoutDetailTab(data: data, type: type, period: $period)
                    .tag(offset + 2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

private struct TabItem {
    let title: String
    let icon: String
    let color: Color
}
