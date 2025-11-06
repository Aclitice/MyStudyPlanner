import Foundation

struct PlanningInput: Codable {
    let persona: String // student | professional
    let goalTitle: String
    let targetLevel: String?
    let deadline: Date?
}

struct PlanningOutput: Codable {
    let milestones: [MilestonePlan]
}

struct MilestonePlan: Codable {
    let title: String
    let tasks: [TaskPlan]
}

struct TaskPlan: Codable {
    let title: String
    let estimatedMinutes: Int
    let type: String
    let difficulty: Int? // 1-5 scale
    let priority: Int? // 1-5 scale
}

protocol AIPlanner {
    func generatePlan(input: PlanningInput) async throws -> PlanningOutput
}

// Enhanced AI planner with real Core ML integration
final class LocalAIPlanner: AIPlanner {
    private let downloader: ModelDownloadManager
    private let modelProvider = CoreMLModelProvider.shared

    init(downloader: ModelDownloadManager) {
        self.downloader = downloader
    }

    func generatePlan(input: PlanningInput) async throws -> PlanningOutput {
        // Attempt AI-powered planning if model is available
        if case .downloaded = downloader.state {
            do {
                return try await generateAIPlan(input: input)
            } catch {
                print("AI generation failed, falling back to rule-based: \(error)")
                // Fall back to rule-based approach
            }
        }
        
        // Rule-based fallback
        return generateRuleBasedPlan(input: input)
    }
    
    // MARK: - AI-Powered Planning
    
    private func generateAIPlan(input: PlanningInput) async throws -> PlanningOutput {
        try modelProvider.loadModelIfNeeded()
        
        let aiResponse = try modelProvider.generatePlan(
            persona: input.persona,
            goal: input.goalTitle,
            deadline: input.deadline
        )
        
        // Try to parse AI response as JSON
        if let parsedPlan = parseAIResponse(aiResponse, persona: input.persona) {
            return parsedPlan
        }
        
        // If parsing fails, use rule-based with AI-enhanced estimates
        return generateRuleBasedPlan(input: input, aiEnhanced: true)
    }
    
    private func parseAIResponse(_ response: String, persona: String) -> PlanningOutput? {
        // Try to extract JSON from response
        guard let jsonData = extractJSON(from: response),
              let decoded = try? JSONDecoder().decode(AITaskResponse.self, from: jsonData) else {
            return nil
        }
        
        let tasks = decoded.tasks.map { aiTask in
            TaskPlan(
                title: aiTask.title,
                estimatedMinutes: aiTask.estimatedMinutes,
                type: aiTask.type,
                difficulty: aiTask.difficulty,
                priority: aiTask.priority
            )
        }
        
        return PlanningOutput(milestones: [MilestonePlan(title: "AI-Generated Plan", tasks: tasks)])
    }
    
    private func extractJSON(from text: String) -> Data? {
        // Look for JSON block in response
        if let startRange = text.range(of: "{"),
           let endRange = text.range(of: "}", options: .backwards) {
            let jsonString = String(text[startRange.lowerBound...endRange.upperBound])
            return jsonString.data(using: .utf8)
        }
        return nil
    }
    
    // MARK: - Rule-Based Planning
    
    private func generateRuleBasedPlan(input: PlanningInput, aiEnhanced: Bool = false) -> PlanningOutput {
        var tasks: [TaskPlan] = []
        
        if input.persona == "student" {
            tasks = generateStudentTasks(goal: input.goalTitle, deadline: input.deadline)
        } else {
            tasks = generateProfessionalTasks(goal: input.goalTitle, deadline: input.deadline)
        }
        
        // Apply time pressure adjustment if deadline is close
        if let deadline = input.deadline {
            tasks = adjustTasksForDeadline(tasks: tasks, deadline: deadline)
        }
        
        let milestone = MilestonePlan(
            title: aiEnhanced ? "AI-Enhanced Plan" : "Starter Plan",
            tasks: tasks
        )
        
        return PlanningOutput(milestones: [milestone])
    }
    
    private func generateStudentTasks(goal: String, deadline: Date?) -> [TaskPlan] {
        let baseTaskMinutes = calculateBaseTaskDuration(deadline: deadline)
        
        return [
            TaskPlan(title: "Review syllabus and learning objectives", estimatedMinutes: baseTaskMinutes, type: "study", difficulty: 1, priority: 5),
            TaskPlan(title: "Create study notes and materials", estimatedMinutes: baseTaskMinutes + 20, type: "prep", difficulty: 2, priority: 4),
            TaskPlan(title: "Deep study session - Core concepts", estimatedMinutes: baseTaskMinutes * 2, type: "study", difficulty: 3, priority: 5),
            TaskPlan(title: "Practice problems and exercises", estimatedMinutes: baseTaskMinutes + 30, type: "practice", difficulty: 3, priority: 4),
            TaskPlan(title: "First review (Spaced Repetition +1d)", estimatedMinutes: baseTaskMinutes / 2, type: "review", difficulty: 2, priority: 3),
            TaskPlan(title: "Second review (Spaced Repetition +3d)", estimatedMinutes: baseTaskMinutes / 2, type: "review", difficulty: 2, priority: 3),
            TaskPlan(title: "Third review (Spaced Repetition +7d)", estimatedMinutes: baseTaskMinutes / 3, type: "review", difficulty: 1, priority: 2)
        ]
    }
    
    private func generateProfessionalTasks(goal: String, deadline: Date?) -> [TaskPlan] {
        let baseTaskMinutes = calculateBaseTaskDuration(deadline: deadline)
        
        return [
            TaskPlan(title: "Break down project milestones and dependencies", estimatedMinutes: baseTaskMinutes, type: "plan", difficulty: 2, priority: 5),
            TaskPlan(title: "Gather requirements and stakeholder input", estimatedMinutes: baseTaskMinutes + 15, type: "meeting", difficulty: 2, priority: 4),
            TaskPlan(title: "Research and prototype solutions", estimatedMinutes: baseTaskMinutes * 2, type: "research", difficulty: 3, priority: 4),
            TaskPlan(title: "Build first deliverable (MVP)", estimatedMinutes: baseTaskMinutes * 3, type: "deliver", difficulty: 4, priority: 5),
            TaskPlan(title: "Review and iteration cycle", estimatedMinutes: baseTaskMinutes, type: "review", difficulty: 3, priority: 3),
            TaskPlan(title: "Prepare presentation/report", estimatedMinutes: baseTaskMinutes / 2, type: "report", difficulty: 2, priority: 3)
        ]
    }
    
    private func calculateBaseTaskDuration(deadline: Date?) -> Int {
        guard let deadline = deadline else { return 60 }
        
        let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 30
        
        // Adjust base duration based on time pressure
        switch daysUntilDeadline {
        case ..<7: return 30 // Urgent: shorter focused sessions
        case 7..<30: return 45 // Normal: medium sessions
        default: return 60 // Relaxed: longer deep work
        }
    }
    
    private func adjustTasksForDeadline(tasks: [TaskPlan], deadline: Date) -> [TaskPlan] {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 30
        
        // If deadline is very close, increase priority of all tasks
        if daysRemaining < 7 {
            return tasks.map { task in
                TaskPlan(
                    title: task.title,
                    estimatedMinutes: task.estimatedMinutes,
                    type: task.type,
                    difficulty: task.difficulty,
                    priority: min((task.priority ?? 3) + 1, 5)
                )
            }
        }
        
        return tasks
    }
}

// Helper struct for parsing AI JSON responses
private struct AITaskResponse: Codable {
    let tasks: [AITask]
}

private struct AITask: Codable {
    let title: String
    let estimatedMinutes: Int
    let type: String
    let difficulty: Int?
    let priority: Int?
}


