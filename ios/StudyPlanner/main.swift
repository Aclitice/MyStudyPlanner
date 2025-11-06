import SwiftUI
import CoreData

@main
struct StudyPlannerApp: App {
    @StateObject private var lockManager = LockManager()
    @StateObject private var appState = AppState()
    @StateObject private var modelDownloader = ModelDownloadManager()
    private let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(lockManager)
                .environmentObject(appState)
                .environmentObject(modelDownloader)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background { lockManager.lock() }
            if newPhase == .active {
                BackgroundTaskManager.shared.register()
                BackgroundTaskManager.shared.scheduleDailyRefresh()
            }
        }
    }
}

