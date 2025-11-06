import SwiftUI
import CoreData
import EventKit

struct PlannerView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var appState: AppState
    @State private var isRequestingCalendar = false
    @State private var message: String = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("快捷规划")) {
                    if appState.persona == "student" {
                        Button("生成复习曲线（含写入日历）") { Task { await generateReviewsAndSchedule() } }
                    } else {
                        Button("建议会议准备窗口（含写入日历）") { Task { await suggestAndScheduleMeetingPrep() } }
                    }
                }
                if !message.isEmpty {
                    Section { Text(message).foregroundColor(.secondary) }
                }
                Section(header: Text("日历")) {
                    Button(isRequestingCalendar ? "申请中…" : "申请权限并写入一个示例事件") {
                        Task { await writeSampleEvent() }
                    }
                    .disabled(isRequestingCalendar)
                    NavigationLink(destination: WeekView()) {
                        Label("打开周视图（调整已安排任务）", systemImage: "calendar")
                    }
                    Button("将未安排任务写入日历") {
                        Task {
                            do {
                                try await CalendarService.shared.requestAccess()
                                let count = try await SchedulingService.scheduleUnplannedTasksAndWriteToCalendar(context: context)
                                message = count > 0 ? "已写入 \(count) 条事件" : "没有可写入的任务"
                            } catch {
                                message = "失败：\(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
            .navigationTitle("计划")
        }
    }

    private func generateReviewsForLatestGoal() async {
        let req = NSFetchRequest<NSManagedObject>(entityName: "Goal")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.fetchLimit = 1
        do {
            if let goal = try context.fetch(req).first, let id = goal.value(forKey: "id") as? UUID {
                try SpacedRepetitionService.generateReviewTasks(for: id, anchor: Date(), context: context)
                message = "已为最新目标生成复习任务。"
            } else {
                message = "未找到目标，请先新建目标。"
            }
        } catch {
            message = "生成失败：\(error.localizedDescription)"
        }
    }

    private func generateReviewsAndSchedule() async {
        await generateReviewsForLatestGoal()
        do {
            try await CalendarService.shared.requestAccess()
            let req = NSFetchRequest<NSManagedObject>(entityName: "Task")
            req.predicate = NSPredicate(format: "type == %@", "review")
            let reviews = try context.fetch(req)
            for t in reviews { try await SchedulingService.scheduleSingleTask(task: t, context: context) }
            message = (message.isEmpty ? "" : message + "\n") + "已写入复习到日历"
        } catch {
            message = "复习写入失败：\(error.localizedDescription)"
        }
    }

    private func suggestMeetingPrep() async {
        do {
            try await CalendarService.shared.requestAccess()
            let store = EKEventStore()
            let windows = MeetingPrepService.suggestPreparationWindows(store: store)
            if let first = windows.first {
                message = "建议准备窗口：\(first.start.formatted(date: .omitted, time: .shortened)) - \(first.end.formatted(date: .omitted, time: .shortened))"
            } else {
                message = "未来 7 天没有可建议的准备窗口。"
            }
        } catch {
            message = "权限或日历读取失败：\(error.localizedDescription)"
        }
    }

    private func suggestAndScheduleMeetingPrep() async {
        await suggestMeetingPrep()
        do {
            try await CalendarService.shared.requestAccess()
            let store = EKEventStore()
            let windows = MeetingPrepService.suggestPreparationWindows(store: store)
            if let win = windows.first {
                // 建一个“会议准备”任务写入日历（不落库任务，仅示例）
                _ = try CalendarService.shared.addEvent(title: "会议准备", start: win.start, end: win.end, notes: "自动推荐")
                message += "\n已写入会议准备到日历"
            }
        } catch {
            message = "会议准备写入失败：\(error.localizedDescription)"
        }
    }

    private func writeSampleEvent() async {
        isRequestingCalendar = true
        defer { isRequestingCalendar = false }
        do {
            try await CalendarService.shared.requestAccess()
            _ = try CalendarService.shared.addEvent(title: "示例计划块", start: Date().addingTimeInterval(120), end: Date().addingTimeInterval(3600), notes: "Planner 示例")
            message = "示例事件已写入专属日历。"
        } catch {
            message = "写入失败：\(error.localizedDescription)"
        }
    }
}


