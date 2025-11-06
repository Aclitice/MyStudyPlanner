import Foundation
import CoreData

@MainActor
final class SharingService: ObservableObject {
    static let shared = SharingService()
    
    @Published var isSharing = false
    @Published var shareError: String?
    @Published var lastShareId: String?
    
    private let apiClient = CommunityAPIClient.shared
    
    private init() {}
    
    // MARK: - Export Goal as Shareable Plan
    
    func createShareablePlan(
        from goal: NSManagedObject,
        context: NSManagedObjectContext
    ) throws -> SharedPlan {
        guard let goalId = goal.value(forKey: "id") as? UUID,
              let title = goal.value(forKey: "title") as? String else {
            throw SharingError.invalidGoal
        }
        
        // Fetch all tasks for this goal
        let taskRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        taskRequest.predicate = NSPredicate(format: "goalId == %@", goalId as CVarArg)
        taskRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        let tasks = try context.fetch(taskRequest)
        
        guard !tasks.isEmpty else {
            throw SharingError.noTasks
        }
        
        // Convert to shared tasks
        let sharedTasks = tasks.enumerated().map { index, task in
            SharedTask(
                title: (task.value(forKey: "title") as? String) ?? "Task",
                estimatedMinutes: Int(task.value(forKey: "estimatedMinutes") as? Int32 ?? 60),
                type: (task.value(forKey: "type") as? String) ?? "study",
                difficulty: Int(task.value(forKey: "difficulty") as? Int16 ?? 2),
                order: index
            )
        }
        
        // Calculate estimated days
        let totalMinutes = sharedTasks.reduce(0) { $0 + $1.estimatedMinutes }
        let estimatedDays = max(1, totalMinutes / (4 * 60)) // Assume 4 hours/day
        
        // Determine category from task types
        let category = determineCategory(from: sharedTasks)
        
        return SharedPlan(
            goalTitle: title,
            tasks: sharedTasks,
            estimatedDays: estimatedDays,
            category: category
        )
    }
    
    // MARK: - Share to Community
    
    func shareGoal(
        goal: NSManagedObject,
        userId: String,
        context: NSManagedObjectContext
    ) async throws -> String {
        isSharing = true
        shareError = nil
        defer { isSharing = false }
        
        let plan = try createShareablePlan(from: goal, context: context)
        
        do {
            let shareId = try await apiClient.sharePlan(plan, userId: userId)
            lastShareId = shareId
            return shareId
        } catch APIError.notImplemented {
            // Generate local share ID for demo
            let demoShareId = "demo-\(UUID().uuidString.prefix(8))"
            lastShareId = demoShareId
            return demoShareId
        } catch {
            shareError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Import Shared Plan
    
    func importSharedPlan(
        shareId: String,
        persona: String,
        context: NSManagedObjectContext
    ) async throws {
        isSharing = true
        shareError = nil
        defer { isSharing = false }
        
        do {
            let plan = try await apiClient.importSharedPlan(shareId: shareId)
            try importPlanToLocalDatabase(plan: plan, persona: persona, context: context)
        } catch APIError.notImplemented {
            throw SharingError.apiNotAvailable
        } catch {
            shareError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Import Community Goal
    
    func importCommunityGoal(
        _ communityGoal: CommunityGoal,
        persona: String,
        context: NSManagedObjectContext
    ) throws {
        // Create local goal
        let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
        goal.setValue(UUID(), forKey: "id")
        goal.setValue(communityGoal.title, forKey: "title")
        goal.setValue(nil, forKey: "targetLevel")
        goal.setValue(nil, forKey: "deadline")
        goal.setValue(3, forKey: "priority") // Medium priority
        goal.setValue(Date(), forKey: "createdAt")
        
        try context.save()
        
        // Note: Community goals don't include task details in the mock
        // In real implementation, would fetch full plan details
    }
    
    // MARK: - Private Helpers
    
    private func importPlanToLocalDatabase(
        plan: SharedPlan,
        persona: String,
        context: NSManagedObjectContext
    ) throws {
        // Create goal
        let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
        let goalId = UUID()
        goal.setValue(goalId, forKey: "id")
        goal.setValue(plan.goalTitle, forKey: "title")
        goal.setValue(nil, forKey: "targetLevel")
        
        // Set deadline based on estimated days
        let deadline = Calendar.current.date(byAdding: .day, value: plan.estimatedDays, to: Date())
        goal.setValue(deadline, forKey: "deadline")
        goal.setValue(3, forKey: "priority")
        goal.setValue(Date(), forKey: "createdAt")
        
        // Create tasks
        for sharedTask in plan.tasks {
            let task = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
            task.setValue(UUID(), forKey: "id")
            task.setValue(sharedTask.title, forKey: "title")
            task.setValue(Int32(sharedTask.estimatedMinutes), forKey: "estimatedMinutes")
            task.setValue(Int16(sharedTask.difficulty), forKey: "difficulty")
            task.setValue("todo", forKey: "status")
            task.setValue(sharedTask.type, forKey: "type")
            task.setValue(nil, forKey: "dueDate")
            task.setValue(goalId, forKey: "goalId")
            task.setValue(Int32(sharedTask.order), forKey: "order")
        }
        
        try context.save()
    }
    
    private func determineCategory(from tasks: [SharedTask]) -> String {
        let types = tasks.map { $0.type }
        
        if types.contains("exam") || types.filter({ $0 == "study" }).count > tasks.count / 2 {
            return "Education"
        } else if types.contains("meeting") || types.contains("deliver") {
            return "Professional"
        } else if types.contains("practice") {
            return "Skills"
        }
        
        return "General"
    }
}

enum SharingError: LocalizedError {
    case invalidGoal
    case noTasks
    case apiNotAvailable
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidGoal:
            return "Invalid goal data"
        case .noTasks:
            return "Goal has no tasks to share"
        case .apiNotAvailable:
            return "Community API is not available yet. This feature is coming soon!"
        case .importFailed(let reason):
            return "Failed to import plan: \(reason)"
        }
    }
}
