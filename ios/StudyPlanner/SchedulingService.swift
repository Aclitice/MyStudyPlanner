import Foundation
import CoreData

@MainActor
final class SchedulingService {
    static func scheduleUnplannedTasksAndWriteToCalendar(context: NSManagedObjectContext) async throws -> Int {
        // Fetch all tasks
        let taskRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
        taskRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        let tasks = try context.fetch(taskRequest)

        // Build set of planned taskIds
        let blockRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleBlock")
        let blocks = try context.fetch(blockRequest)
        let plannedTaskIds: Set<UUID> = Set(blocks.compactMap { $0.value(forKey: "taskId") as? UUID })
        
        // Filter unplanned tasks
        let unplannedTasks = tasks.filter { task in
            guard let taskId = task.value(forKey: "id") as? UUID else { return false }
            return !plannedTaskIds.contains(taskId)
        }
        
        // Sort by priority using PriorityEngine
        let prioritized = PriorityEngine.prioritizeTasks(unplannedTasks)

        var pointer = roundUp(date: Date(), toMinutes: 30)
        var scheduledCount = 0

        for (task, priority) in prioritized {
            guard let taskId = task.value(forKey: "id") as? UUID else { continue }

            let title = (task.value(forKey: "title") as? String) ?? "任务"
            let minutes = (task.value(forKey: "estimatedMinutes") as? Int) ?? 30
            let dueDate = task.value(forKey: "dueDate") as? Date

            var start = pointer
            var end = start.addingTimeInterval(TimeInterval(minutes * 60))

            // Respect due date constraints
            if let dueDate, end > dueDate {
                // Try schedule before dueDate
                start = max(Date(), dueDate.addingTimeInterval(TimeInterval(-minutes * 60)))
                end = start.addingTimeInterval(TimeInterval(minutes * 60))
                if end > dueDate { continue }
            }
            
            // Apply time-of-day preference for difficult tasks
            let preferredTime = PriorityEngine.suggestTimeOfDay(for: task)
            start = adjustForTimeOfDay(start: start, preferredTime: preferredTime)
            end = start.addingTimeInterval(TimeInterval(minutes * 60))

            // Conflict avoidance: find next free slot
            if let freeStart = CalendarService.shared.findNextFreeSlot(startingAt: start, durationMinutes: minutes) {
                start = freeStart
                end = start.addingTimeInterval(TimeInterval(minutes * 60))
            }

            // Create calendar event
            let identifier = try CalendarService.shared.addEvent(title: title, start: start, end: end, notes: "由 StudyPlanner 安排 (优先级: \(String(format: "%.0f", priority.score)))")
            await NotificationManager.shared.scheduleReminder(title: title, body: "即将开始", at: start.addingTimeInterval(-300), identifier: identifier)

            // Persist schedule block
            let block = NSEntityDescription.insertNewObject(forEntityName: "ScheduleBlock", into: context)
            block.setValue(UUID(), forKey: "id")
            block.setValue(taskId, forKey: "taskId")
            block.setValue(start, forKey: "start")
            block.setValue(end, forKey: "end")
            block.setValue(false, forKey: "locked")
            block.setValue(identifier, forKey: "eventIdentifier")

            scheduledCount += 1
            
            // Add recommended break time
            let breakMinutes = PriorityEngine.recommendedBreakMinutes(after: task)
            pointer = end.addingTimeInterval(TimeInterval(breakMinutes * 60))
        }

        if context.hasChanges {
            try context.save()
        }
        return scheduledCount
    }

    static func scheduleSingleTask(task: NSManagedObject, context: NSManagedObjectContext) async throws {
        let title = (task.value(forKey: "title") as? String) ?? "任务"
        let minutes = (task.value(forKey: "estimatedMinutes") as? Int) ?? 30
        var start = roundUp(date: Date(), toMinutes: 30)
        if let free = CalendarService.shared.findNextFreeSlot(startingAt: start, durationMinutes: minutes) { start = free }
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let id = try CalendarService.shared.addEvent(title: title, start: start, end: end)
        await NotificationManager.shared.scheduleReminder(title: title, body: "即将开始", at: start.addingTimeInterval(-300), identifier: id)
        let block = NSEntityDescription.insertNewObject(forEntityName: "ScheduleBlock", into: context)
        block.setValue(UUID(), forKey: "id")
        block.setValue(task.value(forKey: "id") as? UUID, forKey: "taskId")
        block.setValue(start, forKey: "start")
        block.setValue(end, forKey: "end")
        block.setValue(false, forKey: "locked")
        block.setValue(id, forKey: "eventIdentifier")
        try context.save()
    }

    private static func roundUp(date: Date, toMinutes: Int) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let remainder = minute % toMinutes
        let add = remainder == 0 ? 0 : (toMinutes - remainder)
        return calendar.date(byAdding: .minute, value: add, to: date) ?? date
    }
    
    // MARK: - Time of Day Optimization
    
    /// Adjust start time to match preferred time of day (if reasonable)
    private static func adjustForTimeOfDay(start: Date, preferredTime: TimeOfDay) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: start)
        let (preferredStart, preferredEnd) = preferredTime.timeRange
        
        // If already in preferred range, keep it
        if hour >= preferredStart && hour < preferredEnd {
            return start
        }
        
        // If start is before preferred time and there's room, shift to preferred start
        if hour < preferredStart {
            let components = calendar.dateComponents([.year, .month, .day], from: start)
            if let adjusted = calendar.date(bySettingHour: preferredStart, minute: 0, second: 0, of: calendar.date(from: components)!) {
                // Only adjust if not too far in future (within 24 hours)
                if adjusted.timeIntervalSince(start) < 24 * 60 * 60 {
                    return adjusted
                }
            }
        }
        
        // Otherwise keep original time
        return start
    }
}


