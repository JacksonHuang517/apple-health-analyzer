import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("stateRemindersEnabled") private var remindersEnabled = false
    @State private var permissionGranted: Bool? = nil
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)

                            Image(systemName: "bell.badge.waveform.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("状态提醒")
                                .font(.headline)
                            Text("基于 HRV 心率变异性评估身体状态，定时推送提醒")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("提醒设置") {
                    Toggle(isOn: $remindersEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("每日状态提醒")
                                Text("9:00 · 12:30 · 17:00")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .onChange(of: remindersEnabled) { _, newVal in
                        handleToggle(newVal)
                    }
                }

                Section("提醒时段") {
                    reminderRow(icon: "sunrise.fill", color: .orange, time: "09:00", label: "早间状态",
                                desc: "查看今日身体恢复状况")
                    reminderRow(icon: "sun.max.fill", color: .yellow, time: "12:30", label: "午间状态",
                                desc: "了解当前身体状态")
                    reminderRow(icon: "sunset.fill", color: .indigo, time: "17:00", label: "下午状态",
                                desc: "回顾今日身体变化")
                }

                Section("状态说明") {
                    stateExplainRow(state: .excellent)
                    stateExplainRow(state: .good)
                    stateExplainRow(state: .normal)
                    stateExplainRow(state: .tired)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("关于 HRV", systemImage: "info.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                        Text("心率变异性（HRV）反映自主神经系统的活跃度。较高的 HRV 通常代表身体恢复良好、压力较低。Apple Watch 会在佩戴期间自动测量。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("通知设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("需要通知权限", isPresented: $showPermissionAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {
                    remindersEnabled = false
                }
            } message: {
                Text("请在设置中开启通知权限，以接收状态提醒")
            }
        }
    }

    private func handleToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await StateNotificationManager.shared.requestNotificationPermission()
                await MainActor.run {
                    if granted {
                        StateNotificationManager.shared.scheduleDailyReminders(enabled: true)
                        StateNotificationManager.shared.enableHRVBackgroundDelivery()
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        } else {
            StateNotificationManager.shared.scheduleDailyReminders(enabled: false)
        }
    }

    private func reminderRow(icon: String, color: Color, time: String, label: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(time)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func stateExplainRow(state: BodyState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: state.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: state.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(state.color)
                Text(state.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
