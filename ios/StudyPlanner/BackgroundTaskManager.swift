import Foundation
import BackgroundTasks
import CoreData

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let refreshTaskId = "com.example.studyplanner.refresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleDailyRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleDailyRefresh()
        let context = PersistenceController.shared.container.viewContext
        Task {
            do {
                _ = try await SchedulingService.scheduleUnplannedTasksAndWriteToCalendar(context: context)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
}


