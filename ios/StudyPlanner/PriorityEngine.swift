import Foundation
import CoreData

struct TaskPriority {
    let taskId: UUID
    let score: Double
    let urgency: Double
    let importance: Double
    let difficulty: Double
}

/// Priority scoring algorithm for intelligent task scheduling
final class PriorityEngine {
    
    // MARK: - Priority Calculation
    
    /// Calculate priority score for a task (0.0 - 100.0, higher is more urgent/important)
    static func calculatePriority(
        task: NSManagedObject,
        currentDate: Date = Date()
    ) -> TaskPriority {
        guard let taskId = task.value(forKey: "id") as? UUID else {
            return TaskPriority(taskId: UUID(), score: 0, urgency: 0, importance: 0, difficulty: 0)
        }
        
        // Calculate individual factors
        let urgency = calculateUrgency(task: task, currentDate: currentDate)
        let importance = calculateImportance(task: task)
        let difficulty = calculateDifficultyFactor(task: task)
        
        // Weighted scoring formula
        // Urgency: 40%, Importance: 35%, Difficulty: 25%
        let score = (urgency * 0.40) + (importance * 0.35) + (difficulty * 0.25)
        
        return TaskPriority(
            taskId: taskId,
            score: score,
            urgency: urgency,
            importance: importance,
            difficulty: difficulty
        )
    }
    
    // MARK: - Urgency Calculation
    
    /// Calculate urgency based on deadline proximity (0-100)
    private static func calculateUrgency(task: NSManagedObject, currentDate: Date) -> Double {
        guard let dueDate = task.value(forKey: "dueDate") as? Date else {
            // No deadline = moderate urgency (40)
            return 40.0
        }
        
        let timeRemaining = dueDate.timeIntervalSince(currentDate)
        let daysRemaining = timeRemaining / (24 * 60 * 60)
        
        // Urgency curve
        switch daysRemaining {
        case ..<0:
            return 100.0 // Overdue: maximum urgency
        case 0..<1:
            return 95.0 // Due today
        case 1..<2:
            return 85.0 // Due tomorrow
        case 2..<3:
            return 75.0 // Due in 2 days
        case 3..<7:
            return 60.0 // Due this week
        case 7..<14:
            return 45.0 // Due in 2 weeks
        case 14..<30:
            return 30.0 // Due this month
        default:
            return 20.0 // Future deadline
        }
    }
    
    // MARK: - Importance Calculation
    
    /// Calculate importance based on task type and explicit priority (0-100)
    private static func calculateImportance(task: NSManagedObject) -> Double {
        let taskType = task.value(forKey: "type") as? String ?? "study"
        
        // Type-based importance
        var baseImportance: Double
        switch taskType {
        case "exam", "deliver":
            baseImportance = 90.0 // Critical deliverables
        case "study", "practice":
            baseImportance = 70.0 // Core learning
        case "review":
            baseImportance = 60.0 // Reinforcement
        case "meeting", "plan":
            baseImportance = 65.0 // Professional obligations
        case "prep", "research":
            baseImportance = 50.0 // Preparatory work
        default:
            baseImportance = 40.0 // General tasks
        }
        
        // Adjust for explicit difficulty (proxy for importance in some contexts)
        if let difficulty = task.value(forKey: "difficulty") as? Int16 {
            // Higher difficulty tasks may be foundational and thus more important
            let difficultyBonus = Double(difficulty - 1) * 5.0 // Up to +20 for difficulty 5
            baseImportance = min(100.0, baseImportance + difficultyBonus)
        }
        
        return baseImportance
    }
    
    // MARK: - Difficulty Factor
    
    /// Calculate difficulty scheduling factor (0-100)
    /// Higher scores mean "schedule earlier" (harder tasks when fresh)
    private static func calculateDifficultyFactor(task: NSManagedObject) -> Double {
        let difficulty = task.value(forKey: "difficulty") as? Int16 ?? 1
        let estimatedMinutes = task.value(forKey: "estimatedMinutes") as? Int32 ?? 60
        
        // Difficulty score (1-5 scale to 0-100)
        let difficultyScore = Double(difficulty - 1) * 25.0 // 0, 25, 50, 75, 100
        
        // Time commitment factor (longer tasks scheduled with more care)
        var timeScore: Double
        switch estimatedMinutes {
        case 0..<30:
            timeScore = 20.0 // Quick tasks
        case 30..<60:
            timeScore = 40.0 // Medium tasks
        case 60..<120:
            timeScore = 60.0 // Long tasks
        case 120..<240:
            timeScore = 80.0 // Very long tasks
        default:
            timeScore = 90.0 // Marathon sessions
        }
        
        // Combine: 60% difficulty, 40% time
        return (difficultyScore * 0.6) + (timeScore * 0.4)
    }
    
    // MARK: - Batch Prioritization
    
    /// Sort tasks by priority score
    static func prioritizeTasks(_ tasks: [NSManagedObject]) -> [(task: NSManagedObject, priority: TaskPriority)] {
        let prioritized = tasks.map { task in
            (task: task, priority: calculatePriority(task: task))
        }
        
        return prioritized.sorted { $0.priority.score > $1.priority.score }
    }
    
    // MARK: - Smart Scheduling Suggestions
    
    /// Determine optimal time of day for a task based on difficulty
    static func suggestTimeOfDay(for task: NSManagedObject) -> TimeOfDay {
        let difficulty = task.value(forKey: "difficulty") as? Int16 ?? 1
        let estimatedMinutes = task.value(forKey: "estimatedMinutes") as? Int32 ?? 60
        
        // High difficulty or long tasks → morning (peak mental energy)
        if difficulty >= 4 || estimatedMinutes >= 120 {
            return .morning
        }
        
        // Medium difficulty → afternoon
        if difficulty >= 2 {
            return .afternoon
        }
        
        // Low difficulty or quick tasks → evening or flexible
        return .evening
    }
    
    /// Calculate recommended break time after task
    static func recommendedBreakMinutes(after task: NSManagedObject) -> Int {
        let estimatedMinutes = task.value(forKey: "estimatedMinutes") as? Int32 ?? 60
        let difficulty = task.value(forKey: "difficulty") as? Int16 ?? 1
        
        // Break duration based on task intensity
        let baseBreak = estimatedMinutes / 4 // 25% of task duration
        let difficultyMultiplier = Double(difficulty) / 3.0 // 0.33 to 1.67
        
        return min(30, max(5, Int(Double(baseBreak) * difficultyMultiplier)))
    }
}

enum TimeOfDay: String {
    case morning = "morning" // 6:00 - 12:00
    case afternoon = "afternoon" // 12:00 - 18:00
    case evening = "evening" // 18:00 - 23:00
    
    var timeRange: (start: Int, end: Int) {
        switch self {
        case .morning: return (6, 12)
        case .afternoon: return (12, 18)
        case .evening: return (18, 23)
        }
    }
}
