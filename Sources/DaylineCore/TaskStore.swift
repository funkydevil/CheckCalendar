import Foundation
import Observation

@MainActor
@Observable
public final class TaskStore {
    public private(set) var tasks: [DayTask]
    public private(set) var persistenceError: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored public let calendar: Calendar

    public init(fileURL: URL? = nil, calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.fileURL = fileURL ?? Self.defaultFileURL

        do {
            self.tasks = try Self.load(from: self.fileURL)
            self.persistenceError = nil
        } catch {
            self.tasks = []
            self.persistenceError = "Could not open saved tasks: \(error.localizedDescription)"
        }
    }

    @discardableResult
    public func addTask(
        title: String,
        notes: String = "",
        scheduledDay: Date,
        startMinutes: Int,
        durationMinutes: Int,
        colorHex: String
    ) -> DayTask {
        let normalizedStart = min(max(startMinutes, 0), 1_425)
        let normalizedDuration = min(max(durationMinutes, 15), 1_440 - normalizedStart)
        let task = DayTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledDay: calendar.startOfDay(for: scheduledDay),
            startMinutes: normalizedStart,
            durationMinutes: normalizedDuration,
            colorHex: colorHex
        )
        tasks.append(task)
        sortTasks()
        persist()
        return task
    }

    public func updateTask(_ task: DayTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = updated.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.scheduledDay = calendar.startOfDay(for: updated.scheduledDay)
        updated.startMinutes = min(max(updated.startMinutes, 0), 1_425)
        updated.durationMinutes = min(max(updated.durationMinutes, 15), 1_440 - updated.startMinutes)
        updated.lastEditedAt = .now
        tasks[index] = updated
        sortTasks()
        persist()
    }

    public func toggleCompletion(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }), !tasks[index].isMoved else { return }
        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? .now : nil
        tasks[index].lastEditedAt = .now
        persist()
    }

    public func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    public func moveTask(id: UUID, to requestedStartMinutes: Int) -> Int? {
        guard let index = tasks.firstIndex(where: { $0.id == id }), !tasks[index].isMoved else { return nil }
        let task = tasks[index]
        let maximumStart = 1_440 - task.durationMinutes
        let requested = min(max(Self.snapToQuarterHour(requestedStartMinutes), 0), maximumStart)
        let candidates = stride(from: 0, through: maximumStart, by: 15)
            .filter { isSlotAvailable(for: task, startMinutes: $0, durationMinutes: task.durationMinutes) }
        guard let destination = candidates.min(by: {
            let leftDistance = abs($0 - requested)
            let rightDistance = abs($1 - requested)
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            return requested >= task.startMinutes ? $0 > $1 : $0 < $1
        }) else { return nil }

        tasks[index].startMinutes = destination
        tasks[index].lastEditedAt = .now
        sortTasks()
        persist()
        return destination
    }

    @discardableResult
    public func resizeTask(id: UUID, to requestedDurationMinutes: Int) -> Int? {
        guard let task = tasks.first(where: { $0.id == id }),
              let plan = TaskResizePlanner.resizeFromBottom(
                  tasks: tasks(on: task.scheduledDay),
                  taskID: id,
                  requestedDurationMinutes: requestedDurationMinutes
              ),
              let selectedTiming = plan[id] else { return nil }
        applyResizePlan(plan)
        return selectedTiming.durationMinutes
    }

    @discardableResult
    public func resizeTaskFromTop(id: UUID, to requestedStartMinutes: Int) -> Int? {
        guard let task = tasks.first(where: { $0.id == id }),
              let plan = TaskResizePlanner.resizeFromTop(
                  tasks: tasks(on: task.scheduledDay),
                  taskID: id,
                  requestedStartMinutes: requestedStartMinutes
              ),
              let selectedTiming = plan[id] else { return nil }
        applyResizePlan(plan)
        return selectedTiming.startMinutes
    }

    @discardableResult
    public func moveUnfinishedTasksToTomorrow(from sourceDate: Date) -> Int {
        let sourceDay = calendar.startOfDay(for: sourceDate)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: sourceDay) else { return 0 }
        let indices = tasks.indices.filter {
            calendar.isDate(tasks[$0].scheduledDay, inSameDayAs: sourceDay) && tasks[$0].isActionable
        }
        guard !indices.isEmpty else { return 0 }

        var copies: [DayTask] = []
        for index in indices {
            tasks[index].movedToDate = tomorrow
            tasks[index].lastEditedAt = .now

            let source = tasks[index]
            copies.append(
                DayTask(
                    title: source.title,
                    notes: source.notes,
                    scheduledDay: tomorrow,
                    startMinutes: source.startMinutes,
                    durationMinutes: source.durationMinutes,
                    colorHex: source.colorHex,
                    carriedFromTaskID: source.id
                )
            )
        }

        tasks.append(contentsOf: copies)
        sortTasks()
        persist()
        return copies.count
    }

    public func tasks(on date: Date) -> [DayTask] {
        tasks
            .filter { calendar.isDate($0.scheduledDay, inSameDayAs: date) }
            .sorted(by: Self.taskSort)
    }

    public func unfinishedCount(on date: Date) -> Int {
        tasks(on: date).count(where: \.isActionable)
    }

    public func suggestedStartMinutes(on date: Date, fallback: Int) -> Int {
        guard let latestEnd = tasks(on: date).map(\.endMinutes).max() else {
            return min(max(Self.snapUpToQuarterHour(fallback), 0), 1_425)
        }
        return min(Self.snapUpToQuarterHour(latestEnd), 1_425)
    }

    public func summary(for date: Date) -> DaySummary {
        let day = calendar.startOfDay(for: date)
        let dayTasks = tasks(on: day)
        return DaySummary(
            date: day,
            total: dayTasks.count,
            completed: dayTasks.count(where: \.isCompleted),
            moved: dayTasks.count(where: \.isMoved),
            scheduledMinutes: dayTasks.reduce(0) { $0 + $1.durationMinutes }
        )
    }

    public var history: [DaySummary] {
        let days = Set(tasks.map { calendar.startOfDay(for: $0.scheduledDay) })
        return days.map(summary(for:)).sorted { $0.date > $1.date }
    }

    public func flush() throws {
        try Self.save(tasks, to: fileURL)
        persistenceError = nil
    }

    public func clearPersistenceError() {
        persistenceError = nil
    }

    private func sortTasks() {
        tasks.sort(by: Self.taskSort)
    }

    private func applyResizePlan(_ plan: TaskResizePlan) {
        let editedAt = Date.now
        for (taskID, timing) in plan.timings {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { continue }
            tasks[index].startMinutes = timing.startMinutes
            tasks[index].durationMinutes = timing.durationMinutes
            tasks[index].lastEditedAt = editedAt
        }
        sortTasks()
        persist()
    }

    private func isSlotAvailable(
        for task: DayTask,
        startMinutes: Int,
        durationMinutes: Int
    ) -> Bool {
        let endMinutes = startMinutes + durationMinutes
        return tasks.allSatisfy { other in
            guard other.id != task.id,
                  calendar.isDate(other.scheduledDay, inSameDayAs: task.scheduledDay) else { return true }
            return endMinutes <= other.startMinutes || startMinutes >= other.endMinutes
        }
    }

    private func persist() {
        do {
            try flush()
        } catch {
            persistenceError = "Could not save changes: \(error.localizedDescription)"
        }
    }

    private static func taskSort(_ lhs: DayTask, _ rhs: DayTask) -> Bool {
        if lhs.scheduledDay != rhs.scheduledDay { return lhs.scheduledDay < rhs.scheduledDay }
        if lhs.startMinutes != rhs.startMinutes { return lhs.startMinutes < rhs.startMinutes }
        return lhs.createdAt < rhs.createdAt
    }

    private static func snapToQuarterHour(_ minutes: Int) -> Int {
        Int((Double(minutes) / 15).rounded()) * 15
    }

    private static func snapUpToQuarterHour(_ minutes: Int) -> Int {
        ((minutes + 14) / 15) * 15
    }

    private static var defaultFileURL: URL {
        let arguments = CommandLine.arguments
        if let flagIndex = arguments.firstIndex(of: "--store-path"),
           arguments.indices.contains(flagIndex + 1) {
            return URL(fileURLWithPath: arguments[flagIndex + 1], isDirectory: false)
        }
        if let overridePath = ProcessInfo.processInfo.environment["DAYLINE_STORE_PATH"],
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: false)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("Dayline", isDirectory: true)
            .appendingPathComponent("tasks.json", isDirectory: false)
    }

    private static func load(from url: URL) throws -> [DayTask] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DayTask].self, from: data)
    }

    private static func save(_ tasks: [DayTask], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(tasks).write(to: url, options: .atomic)
    }
}
