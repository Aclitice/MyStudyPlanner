import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(entity: NSEntityDescription.entity(forEntityName: "Task", in: PersistenceController.shared.container.viewContext)!, sortDescriptors: [NSSortDescriptor(key: "order", ascending: true)]) private var tasks: FetchedResults<NSManagedObject>
    @State private var showNewGoal: Bool = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            List {
                header
                taskSection
            }
            .navigationTitle("Study Planner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewGoal = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNewGoal) { NewGoalView() }
        }
    }

    private var header: some View {
        Section {
            HStack {
                Image(systemName: appState.persona == "student" ? "graduationcap" : "briefcase")
                    .foregroundColor(.accentColor)
                Text(appState.persona == "student" ? "学生模式" : "职场模式")
                Spacer()
                if appState.persona == "student" {
                    Text("建议：安排复习曲线")
                        .foregroundColor(.secondary)
                } else {
                    Text("建议：为会议预留准备时间")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var taskSection: some View {
        Group {
            if tasks.isEmpty {
                Text("暂无任务，点击右上角 + 创建目标并自动生成任务")
                    .foregroundColor(.secondary)
            } else {
                ForEach(tasks, id: \.self) { task in
                    HStack {
                        Text(task.value(forKey: "title") as? String ?? "任务")
                        Spacer()
                        if isTaskScheduled(task) {
                            Image(systemName: "calendar.badge.checkmark").foregroundColor(.green)
                        }
                        Text("\(task.value(forKey: "estimatedMinutes") as? Int ?? 0)m").foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { try? await SchedulingService.scheduleSingleTask(task: task, context: context) }
                        } label: { Label("写入日历", systemImage: "calendar.badge.plus") }
                        .tint(.blue)
                        Button(role: .destructive) {
                            Task { await removeTaskFromCalendar(task) }
                        } label: { Label("撤销日历", systemImage: "calendar.badge.minus") }
                    }
                }
                .onMove(perform: move)
            }
        }
    }

    private func isTaskScheduled(_ task: NSManagedObject) -> Bool {
        guard let taskId = task.value(forKey: "id") as? UUID else { return false }
        let req = NSFetchRequest<NSManagedObject>(entityName: "ScheduleBlock")
        req.predicate = NSPredicate(format: "taskId == %@", taskId as CVarArg)
        let count = (try? context.count(for: req)) ?? 0
        return count > 0
    }

    private func removeTaskFromCalendar(_ task: NSManagedObject) async {
        do {
            let req = NSFetchRequest<NSManagedObject>(entityName: "ScheduleBlock")
            if let taskId = task.value(forKey: "id") as? UUID {
                req.predicate = NSPredicate(format: "taskId == %@", taskId as CVarArg)
                if let block = try context.fetch(req).first,
                   let eventId = block.value(forKey: "eventIdentifier") as? String {
                    try CalendarService.shared.deleteEvent(identifier: eventId)
                    context.delete(block)
                    try context.save()
                }
            }
        } catch {
            print("removeTaskFromCalendar error: \(error)")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = tasks.map { $0 }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, obj) in ordered.enumerated() {
            obj.setValue(Int32(index), forKey: "order")
        }
        do { try context.save() } catch { print("reorder save error: \(error)") }
    }
}


