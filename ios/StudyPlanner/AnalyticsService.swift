import Foundation
import CoreData

struct StudyAnalytics {
    let totalStudyMinutes: Int
    let tasksCompleted: Int
    let averageFocusScore: Double
    let studyStreak: Int
    let weeklyProgress: [DailyProgress]
    let goalProgress: [GoalProgress]
}

struct DailyProgress {
    let date: Date
    let minutes: Int
    let tasksCompleted: Int
}

struct GoalProgress {
    let goalId: UUID
    let goalTitle: String
    let totalTasks: Int
    let completedTasks: Int
    let totalMinutes: Int
    var completionPercentage: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks) * 100.0
    }
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Track Study Sessions
    
    func recordTaskCompletion(
        taskId: UUID,
        goalId: UUID?,
        plannedMinutes: Int,
        actualMinutes: Int,
        focusScore: Double? = nil,
        context: NSManagedObjectContext
    ) throws {
        let stats = NSEntityDescription.insertNewObject(forEntityName: "StudyStats", into: context)
        stats.setValue(UUID(), forKey: "id")
        stats.setValue(Date(), forKey: "date")
        stats.setValue(taskId, forKey: "taskId")
        stats.setValue(goalId, forKey: "goalId")
        stats.setValue(Int32(plannedMinutes), forKey: "plannedMinutes")
        stats.setValue(Int32(actualMinutes), forKey: "actualMinutes")
        stats.setValue("completed", forKey: "completionStatus")
        
        if let focusScore = focusScore {
            stats.setValue(focusScore, forKey: "focusScore")
        }
        
        try context.save()
    }
    
    func recordTaskSkipped(taskId: UUID, goalId: UUID?, reason: String?, context: NSManagedObjectContext) throws {
        let stats = NSEntityDescription.insertNewObject(forEntityName: "StudyStats", into: context)
        stats.setValue(UUID(), forKey: "id")
        stats.setValue(Date(), forKey: "date")
        stats.setValue(taskId, forKey: "taskId")
        stats.setValue(goalId, forKey: "goalId")
        stats.setValue(0, forKey: "plannedMinutes")
        stats.setValue(0, forKey: "actualMinutes")
        stats.setValue("skipped", forKey: "completionStatus")
        stats.setValue(reason, forKey: "notes")
        
        try context.save()
    }
    
    // MARK: - Analytics Queries
    
    func getAnalytics(for period: AnalyticsPeriod, context: NSManagedObjectContext) throws -> StudyAnalytics {
        let startDate = period.startDate
        let endDate = Date()
        
        // Fetch stats for period
        let statsRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyStats")
        statsRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        let stats = try context.fetch(statsRequest)
        
        // Calculate totals
        let totalMinutes = stats.reduce(0) { $0 + (($1.value(forKey: "actualMinutes") as? Int32) ?? 0) }
        let completedStats = stats.filter { ($0.value(forKey: "completionStatus") as? String) == "completed" }
        let tasksCompleted = completedStats.count
        
        // Calculate average focus score
        let focusScores = stats.compactMap { $0.value(forKey: "focusScore") as? Double }
        let avgFocus = focusScores.isEmpty ? 0.0 : focusScores.reduce(0, +) / Double(focusScores.count)
        
        // Calculate study streak
        let streak = try calculateStudyStreak(context: context)
        
        // Weekly progress
        let weeklyProgress = try calculateWeeklyProgress(stats: stats)
        
        // Goal progress
        let goalProgress = try calculateGoalProgress(context: context)
        
        return StudyAnalytics(
            totalStudyMinutes: Int(totalMinutes),
            tasksCompleted: tasksCompleted,
            averageFocusScore: avgFocus,
            studyStreak: streak,
            weeklyProgress: weeklyProgress,
            goalProgress: goalProgress
        )
    }
    
    private func calculateStudyStreak(context: NSManagedObjectContext) throws -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        // Look back up to 365 days
        for _ in 0..<365 {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            
            let request = NSFetchRequest<NSManagedObject>(entityName: "StudyStats")
            request.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND completionStatus == %@",
                checkDate as NSDate,
                nextDay as NSDate,
                "completed"
            )
            
            let count = try context.count(for: request)
            
            if count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateWeeklyProgress(stats: [NSManagedObject]) -> [DailyProgress] {
        let calendar = Calendar.current
        var dailyMap: [Date: (minutes: Int, tasks: Int)] = [:]
        
        for stat in stats {
            guard let date = stat.value(forKey: "date") as? Date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let minutes = (stat.value(forKey: "actualMinutes") as? Int32) ?? 0
            let isCompleted = (stat.value(forKey: "completionStatus") as? String) == "completed"
            
            var current = dailyMap[dayStart] ?? (minutes: 0, tasks: 0)
            current.minutes += Int(minutes)
            if isCompleted {
                current.tasks += 1
            }
            dailyMap[dayStart] = current
        }
        
        // Get last 7 days
        var result: [DailyProgress] = []
        for i in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            let data = dailyMap[dayStart] ?? (minutes: 0, tasks: 0)
            result.append(DailyProgress(date: dayStart, minutes: data.minutes, tasksCompleted: data.tasks))
        }
        
        return result
    }
    
    private func calculateGoalProgress(context: NSManagedObjectContext) throws -> [GoalProgress] {
        let goalRequest = NSFetchRequest<NSManagedObject>(entityName: "Goal")
        goalRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let goals = try context.fetch(goalRequest)
        
        var progressArray: [GoalProgress] = []
        
        for goal in goals {
            guard let goalId = goal.value(forKey: "id") as? UUID,
                  let title = goal.value(forKey: "title") as? String else { continue }
            
            // Get all tasks for this goal
            let taskRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
            taskRequest.predicate = NSPredicate(format: "goalId == %@", goalId as CVarArg)
            let tasks = try context.fetch(taskRequest)
            
            let totalTasks = tasks.count
            let completedTasks = tasks.filter { ($0.value(forKey: "status") as? String) == "done" }.count
            
            // Get total study time from stats
            let statsRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyStats")
            statsRequest.predicate = NSPredicate(format: "goalId == %@", goalId as CVarArg)
            let stats = try context.fetch(statsRequest)
            let totalMinutes = stats.reduce(0) { $0 + (($1.value(forKey: "actualMinutes") as? Int32) ?? 0) }
            
            progressArray.append(GoalProgress(
                goalId: goalId,
                goalTitle: title,
                totalTasks: totalTasks,
                completedTasks: completedTasks,
                totalMinutes: Int(totalMinutes)
            ))
        }
        
        return progressArray
    }
    
    // MARK: - Quick Stats
    
    func getTodayStats(context: NSManagedObjectContext) throws -> (minutes: Int, tasks: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "StudyStats")
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            today as NSDate,
            tomorrow as NSDate
        )
        
        let stats = try context.fetch(request)
        let minutes = stats.reduce(0) { $0 + (($1.value(forKey: "actualMinutes") as? Int32) ?? 0) }
        let completed = stats.filter { ($0.value(forKey: "completionStatus") as? String) == "completed" }.count
        
        return (minutes: Int(minutes), tasks: completed)
    }
}

enum AnalyticsPeriod {
    case week
    case month
    case year
    case all
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)!
        case .all:
            return calendar.date(byAdding: .year, value: -10, to: now)!
        }
    }
}
