import Foundation
import EventKit
import UIKit

final class CalendarService {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    private let calendarTitle = "Study Planner"
    private let calendarIdKey = "StudyPlanner.CalendarIdentifier"

    func requestAccess() async throws {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "CalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "日历访问被拒绝"]))
                }
            }
        }
    }

    private func getOrCreateCalendar() throws -> EKCalendar {
        if let id = UserDefaults.standard.string(forKey: calendarIdKey), let cal = eventStore.calendar(withIdentifier: id) {
            return cal
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle

        if let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.sources.first {
            calendar.source = source
        }

        calendar.cgColor = UIColor.systemBlue.cgColor
        try eventStore.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdKey)
        return calendar
    }

    /// 返回应用专属日历的 identifier（如不存在则创建）
    func appCalendarIdentifier() throws -> String {
        let cal = try getOrCreateCalendar()
        return cal.calendarIdentifier
    }

    func addEvent(title: String, start: Date, end: Date, notes: String? = nil) throws -> String {
        let calendar = try getOrCreateCalendar()
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = notes
        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func updateEvent(identifier: String, title: String? = nil, start: Date? = nil, end: Date? = nil, notes: String? = nil) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        if let title { event.title = title }
        if let start { event.startDate = start }
        if let end { event.endDate = end }
        if let notes { event.notes = notes }
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Conflict & Availability

    func events(in interval: DateInterval) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return eventStore.events(matching: predicate)
    }

    func findNextFreeSlot(startingAt start: Date, durationMinutes: Int, searchHorizonDays: Int = 14) -> Date? {
        let endHorizon = Calendar.current.date(byAdding: .day, value: searchHorizonDays, to: start) ?? start
        var probeStart = start
        let duration = TimeInterval(durationMinutes * 60)
        let appCalendarId = (try? appCalendarIdentifier())
        while probeStart < endHorizon {
            let probeEnd = probeStart.addingTimeInterval(duration)
            let interval = DateInterval(start: probeStart, end: probeEnd)
            let conflicts = events(in: interval).contains { ev in
                if let appCalendarId, ev.calendar.calendarIdentifier == appCalendarId { return false }
                return ev.startDate < interval.end && ev.endDate > interval.start
            }
            if !conflicts { return probeStart }
            // 前进到最近冲突事件的结束后半小时
            let predicate = eventStore.predicateForEvents(withStart: probeStart, end: probeEnd, calendars: nil)
            let evs = eventStore.events(matching: predicate)
            if let maxEnd = evs.map({ $0.endDate }).max() {
                probeStart = Calendar.current.date(byAdding: .minute, value: 30, to: maxEnd) ?? maxEnd
            } else {
                probeStart = Calendar.current.date(byAdding: .minute, value: 30, to: probeStart) ?? probeStart
            }
        }
        return nil
    }
}


