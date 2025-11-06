import SwiftUI

struct ContentView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                TabView {
                    HomeView()
                        .tabItem { Label("主页", systemImage: "house") }
                    PlannerView()
                        .tabItem { Label("计划", systemImage: "calendar") }
                    SettingsView()
                        .tabItem { Label("设置", systemImage: "gear") }
                }
            } else {
                OnboardingView()
            }

            if lockManager.isLocked {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill").font(.largeTitle)
                    Text("已锁定")
                    Button("使用 Face ID 解锁") {
                        Task {
                            _ = await lockManager.unlockWithBiometrics()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .task {
            // 首次进入尝试解锁（若开启）
            _ = await lockManager.unlockWithBiometrics()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var modelDownloader: ModelDownloadManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("身份")) {
                    Picker("身份", selection: $appState.persona) {
                        Text("学生").tag("student")
                        Text("职场人").tag("professional")
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("隐私")) {
                    Toggle("启用 Face ID 上锁", isOn: Binding(
                        get: { lockManager.isFaceIdEnabled },
                        set: { lockManager.isFaceIdEnabled = $0; if $0 { lockManager.lock() } }
                    ))
                    Button("立即锁定") { lockManager.lock() }
                }
                Section(header: Text("本地模型")) {
                    switch modelDownloader.state {
                    case .notDownloaded:
                        Button("下载离线模型（占位）") { Task { await modelDownloader.startDownloadIfNeeded() } }
                    case .downloading(let p):
                        HStack { Text("下载中"); Spacer(); Text(String(format: "%.0f%%", p * 100)) }
                    case .downloaded:
                        Text("模型已就绪")
                    case .failed(let e):
                        Text("下载失败：\(e)")
                    }
                }
                Section(header: Text("日历")) {
                    Button("申请日历访问并创建专属日历") {
                        Task {
                            do {
                                try await CalendarService.shared.requestAccess()
                                _ = try CalendarService.shared.addEvent(title: "欢迎使用 Study Planner", start: Date().addingTimeInterval(60), end: Date().addingTimeInterval(3600), notes: "这是一个示例事件")
                            } catch {
                                print("Calendar error: \(error)")
                            }
                        }
                    }
                }
                Section(header: Text("通知")) {
                    Button("请求通知权限") {
                        Task { _ = await NotificationManager.shared.requestAuthorization() }
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}


