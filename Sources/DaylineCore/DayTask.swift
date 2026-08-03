import Foundation

public struct DayTask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String
    public var scheduledDay: Date
    public var startMinutes: Int
    public var durationMinutes: Int
    public var colorHex: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var movedToDate: Date?
    public var carriedFromTaskID: UUID?
    public let createdAt: Date
    public var lastEditedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        scheduledDay: Date,
        startMinutes: Int,
        durationMinutes: Int,
        colorHex: String = "5B7CFA",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        movedToDate: Date? = nil,
        carriedFromTaskID: UUID? = nil,
        createdAt: Date = .now,
        lastEditedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.scheduledDay = scheduledDay
        self.startMinutes = startMinutes
        self.durationMinutes = durationMinutes
        self.colorHex = colorHex
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.movedToDate = movedToDate
        self.carriedFromTaskID = carriedFromTaskID
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }

    public var endMinutes: Int {
        min(startMinutes + durationMinutes, 1_440)
    }

    public var isMoved: Bool {
        movedToDate != nil
    }

    public var isActionable: Bool {
        !isCompleted && !isMoved
    }
}

public struct DaySummary: Identifiable, Hashable, Sendable {
    public let date: Date
    public let total: Int
    public let completed: Int
    public let moved: Int
    public let scheduledMinutes: Int

    public init(date: Date, total: Int, completed: Int, moved: Int, scheduledMinutes: Int) {
        self.date = date
        self.total = total
        self.completed = completed
        self.moved = moved
        self.scheduledMinutes = scheduledMinutes
    }

    public var id: Date { date }
    public var remaining: Int { max(total - completed - moved, 0) }
    public var resolved: Int { completed + moved }
    public var progress: Double { total == 0 ? 0 : Double(resolved) / Double(total) }
}
