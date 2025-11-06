import Foundation
import CoreData

final class SpacedRepetitionService {
    static func generateReviewTasks(for goalId: UUID, anchor: Date, context: NSManagedObjectContext) throws {
        let dayOffsets = [1, 3, 7, 15, 30]
        for offset in dayOffsets {
            let task = NSEntityDescription.insertNewObject(forEntityName: "Task", into: context)
            task.setValue(UUID(), forKey: "id")
            task.setValue("复习：阶段 \(offset)d", forKey: "title")
            task.setValue(20, forKey: "estimatedMinutes")
            task.setValue(1, forKey: "difficulty")
            task.setValue("todo", forKey: "status")
            task.setValue("review", forKey: "type")
            task.setValue(Calendar.current.date(byAdding: .day, value: offset, to: anchor), forKey: "dueDate")
            task.setValue(goalId, forKey: "goalId")
        }
        try context.save()
    }
}


