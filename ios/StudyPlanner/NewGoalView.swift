import SwiftUI
import CoreData

struct NewGoalView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelDownloader: ModelDownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var targetLevel: String = ""
    @State private var deadline: Date = Date().addingTimeInterval(7*24*3600)
    @State private var isSaving: Bool = false
    private var planner: LocalAIPlanner { LocalAIPlanner(downloader: modelDownloader) }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目标")) {
                    TextField("标题", text: $title)
                    if appState.persona == "student" {
                        TextField("达成水平/分数（可选）", text: $targetLevel)
                    } else {
                        TextField("达成水平/里程碑（可选）", text: $targetLevel)
                    }
                    DatePicker("截止日期", selection: $deadline, displayedComponents: .date)
                }
                if appState.persona == "student" {
                    Section(header: Text("学习偏好")) {
                        Text("后续可加入复习曲线设定、学科标签等")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(header: Text("工作偏好")) {
                        Text("后续可加入会议密度、时区、汇报节奏等")
                            .foregroundColor(.secondary)
                    }
                }
                Section {
                    Button(isSaving ? "生成中…" : "创建并生成计划") { Task { await saveAndPlan() } }
                        .disabled(isSaving || title.isEmpty)
                }
            }
            .navigationTitle("新建目标")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }

    private func saveAndPlan() async {
        isSaving = true
        do {
            try DataService.shared.addGoal(title: title, targetLevel: targetLevel.isEmpty ? nil : targetLevel, deadline: deadline)
            let input = PlanningInput(persona: appState.persona, goalTitle: title, targetLevel: targetLevel.isEmpty ? nil : targetLevel, deadline: deadline)
            let output = try await planner.generatePlan(input: input)
            // 查找刚创建的 Goal
            let req = NSFetchRequest<NSManagedObject>(entityName: "Goal")
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            req.fetchLimit = 1
            if let latest = try context.fetch(req).first, let id = latest.value(forKey: "id") as? UUID {
                try DataService.shared.addTasksForGoal(goalId: id, tasks: output.milestones.flatMap { $0.tasks })
            }
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            print("SaveAndPlan error: \(error)")
        }
    }
}


