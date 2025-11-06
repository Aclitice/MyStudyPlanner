import SwiftUI
import CoreData

struct WeekView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(entity: NSEntityDescription.entity(forEntityName: "ScheduleBlock", in: PersistenceController.shared.container.viewContext)!, sortDescriptors: [NSSortDescriptor(key: "start", ascending: true)]) private var blocks: FetchedResults<NSManagedObject>
    @State private var selectedWeekStart: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: comps) ?? Date()
    }()

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("本周安排")) {
                    ForEach(blocks.filter { inSameWeek($0.value(forKey: "start") as? Date) }, id: \.self) { block in
                        HStack {
                            VStack(alignment: .leading) {
                                if let task = taskForBlock(block) {
                                    Text(task.value(forKey: "title") as? String ?? "任务")
                                        .font(.headline)
                                } else {
                                    Text("未绑定任务")
                                        .font(.headline)
                                }
                                Text(timeRangeText(block))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("+15m") { shift(block: block, byMinutes: 15) }
                            Button("-15m") { shift(block: block, byMinutes: -15) }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("周视图")
        }
    }

    private func inSameWeek(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: selectedWeekStart, toGranularity: .weekOfYear)
    }

    private func taskForBlock(_ block: NSManagedObject) -> NSManagedObject? {
        guard let taskId = block.value(forKey: "taskId") as? UUID else { return nil }
        let req = NSFetchRequest<NSManagedObject>(entityName: "Task")
        req.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        return try? context.fetch(req).first
    }

    private func timeRangeText(_ block: NSManagedObject) -> String {
        let start = block.value(forKey: "start") as? Date ?? Date()
        let end = block.value(forKey: "end") as? Date ?? Date()
        return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func shift(block: NSManagedObject, byMinutes: Int) {
        let start = (block.value(forKey: "start") as? Date ?? Date()).addingTimeInterval(TimeInterval(byMinutes * 60))
        let end = (block.value(forKey: "end") as? Date ?? Date()).addingTimeInterval(TimeInterval(byMinutes * 60))
        block.setValue(start, forKey: "start")
        block.setValue(end, forKey: "end")
        if let id = block.value(forKey: "eventIdentifier") as? String {
            try? CalendarService.shared.updateEvent(identifier: id, start: start, end: end)
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let block = blocks[index]
            if let id = block.value(forKey: "eventIdentifier") as? String {
                try? CalendarService.shared.deleteEvent(identifier: id)
            }
            context.delete(block)
        }
        try? context.save()
    }
}


