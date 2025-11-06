import Foundation
import CoreData

final class DataService: ObservableObject {
    static let shared = DataService(context: PersistenceController.shared.container.viewContext)
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func addGoal(title: String, targetLevel: String?, deadline: Date?) throws {
        let goal = NSEntityDescription.insertNewObject(forEntityName: "Goal", into: context)
        goal.setValue(UUID(), forKey: "id")
        goal.setValue(title, forKey: "title")
        goal.setValue(targetLevel, forKey: "targetLevel")
        goal.setValue(deadline, forKey: "deadline")
        goal.setValue(0, forKey: "priority")
        goal.setValue(Date(), forKey: "createdAt")

        try context.save()
    }

    func addTasksForGoal(goalId: UUID, tasks: [TaskPlan]) throws {
        for t in tasks {
            let task = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
            task.setValue(UUID(), forKey: "id")
            task.setValue(t.title, forKey: "title")
            task.setValue(t.estimatedMinutes, forKey: "estimatedMinutes")
            task.setValue(1, forKey: "difficulty")
            task.setValue("todo", forKey: "status")
            task.setValue(t.type, forKey: "type")
            task.setValue(nil, forKey: "dueDate")
            task.setValue(goalId, forKey: "goalId")
        }
        try context.save()
    }
}


