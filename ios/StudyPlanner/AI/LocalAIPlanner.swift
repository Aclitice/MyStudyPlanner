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
}

protocol AIPlanner {
    func generatePlan(input: PlanningInput) async throws -> PlanningOutput
}

final class LocalAIPlanner: AIPlanner {
    private let downloader: ModelDownloadManager

    init(downloader: ModelDownloadManager) {
        self.downloader = downloader
    }

    func generatePlan(input: PlanningInput) async throws -> PlanningOutput {
        // 若模型已下载，尝试加载 Core ML 并进行占位推理（真实接入需替换）
        if case .downloaded = downloader.state {
            do {
                try CoreMLModelProvider.shared.loadModelIfNeeded()
                _ = try CoreMLModelProvider.shared.generate(text: "为 persona=\(input.persona) 的用户生成计划，目标：\(input.goalTitle)")
            } catch {
                // 加载失败则回退规则模板
            }
        }
        var tasks: [TaskPlan] = []
        if input.persona == "student" {
            tasks = [
                TaskPlan(title: "梳理考点与大纲", estimatedMinutes: 40, type: "study"),
                TaskPlan(title: "建立题库与错题本", estimatedMinutes: 30, type: "prep"),
                TaskPlan(title: "第一轮精读/刷题", estimatedMinutes: 60, type: "study"),
                TaskPlan(title: "首次复习安排（+1d/+3d）", estimatedMinutes: 20, type: "review")
            ]
        } else {
            tasks = [
                TaskPlan(title: "拆解项目里程碑与依赖", estimatedMinutes: 45, type: "plan"),
                TaskPlan(title: "会议准备：需求澄清与资料收集", estimatedMinutes: 30, type: "meeting"),
                TaskPlan(title: "第一个可交付物（MVP）", estimatedMinutes: 60, type: "deliver"),
                TaskPlan(title: "周报模板与节奏设置", estimatedMinutes: 15, type: "report")
            ]
        }
        let output = PlanningOutput(milestones: [MilestonePlan(title: "起步阶段", tasks: tasks)])
        return output
    }
}


