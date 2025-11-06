import Foundation
import EventKit

final class MeetingPrepService {
    static func suggestPreparationWindows(store: EKEventStore, daysAhead: Int = 7) -> [DateInterval] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate).filter { !$0.isAllDay }
        var intervals: [DateInterval] = []
        for event in events {
            // 在会议前 1-2 小时建议准备窗口（简化）
            let prepStart = event.startDate.addingTimeInterval(-2 * 3600)
            let prepEnd = event.startDate.addingTimeInterval(-3600)
            if prepEnd > now { intervals.append(DateInterval(start: max(prepStart, now), end: prepEnd)) }
        }
        return intervals.sorted { $0.start < $1.start }
    }
}


