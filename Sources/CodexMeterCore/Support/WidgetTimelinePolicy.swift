import Foundation

public enum WidgetTimelinePolicy {
    public static func entryDates(start: Date) -> [Date] {
        (0...12).map { increment in
            start.addingTimeInterval(TimeInterval(increment * 5 * 60))
        }
    }
}
