import XCTest
@testable import Dayline

@MainActor
final class TaskStoreTests: XCTestCase {
    func testPersistsAndReloadsCompletion() throws {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let calendar = utcCalendar
        let day = makeDate(year: 2026, month: 8, day: 3)

        let store = TaskStore(fileURL: fixture, calendar: calendar)
        let task = store.addTask(
            title: "  Подготовить релиз  ",
            notes: "Проверить сборку",
            scheduledDay: day,
            startMinutes: 9 * 60,
            durationMinutes: 90,
            colorHex: "5B7CFA"
        )
        store.toggleCompletion(id: task.id)
        try store.flush()

        let reloaded = TaskStore(fileURL: fixture, calendar: calendar)
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.tasks[0].title, "Подготовить релиз")
        XCTAssertTrue(reloaded.tasks[0].isCompleted)
        XCTAssertNotNil(reloaded.tasks[0].completedAt)
    }

    func testDuplicateTaskCopiesContentAndResetsCompletionState() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let original = store.addTask(
            title: "Повторить задачу",
            notes: "С теми же настройками",
            scheduledDay: day,
            startMinutes: 615,
            durationMinutes: 120,
            colorHex: "8B5CF6"
        )
        store.toggleCompletion(id: original.id)

        let duplicate = store.duplicateTask(id: original.id)

        XCTAssertNotNil(duplicate)
        XCTAssertNotEqual(duplicate?.id, original.id)
        XCTAssertEqual(duplicate?.title, original.title)
        XCTAssertEqual(duplicate?.notes, original.notes)
        XCTAssertEqual(duplicate?.scheduledDay, original.scheduledDay)
        XCTAssertEqual(duplicate?.startMinutes, original.endMinutes)
        XCTAssertEqual(duplicate?.durationMinutes, original.durationMinutes)
        XCTAssertEqual(duplicate?.colorHex, original.colorHex)
        XCTAssertFalse(duplicate?.isCompleted ?? true)
        XCTAssertNil(duplicate?.completedAt)
        XCTAssertEqual(store.tasks.count, 2)
    }

    func testDuplicateTaskMovesToNextDayWhenItDoesNotFitAfterOriginal() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let original = store.addTask(
            title: "Вечерняя задача",
            scheduledDay: day,
            startMinutes: 22 * 60,
            durationMinutes: 120,
            colorHex: "5B7CFA"
        )

        let duplicate = store.duplicateTask(id: original.id)

        XCTAssertEqual(duplicate?.scheduledDay, utcCalendar.date(byAdding: .day, value: 1, to: day))
        XCTAssertEqual(duplicate?.startMinutes, 0)
        XCTAssertEqual(duplicate?.durationMinutes, original.durationMinutes)
    }

    func testMovingUnfinishedPreservesHistoryAndIsIdempotent() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let calendar = utcCalendar
        let monday = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: calendar)

        let unfinished = store.addTask(
            title: "Незавершённая",
            scheduledDay: monday,
            startMinutes: 600,
            durationMinutes: 60,
            colorHex: "5B7CFA"
        )
        let completed = store.addTask(
            title: "Готовая",
            scheduledDay: monday,
            startMinutes: 720,
            durationMinutes: 30,
            colorHex: "10B981"
        )
        store.toggleCompletion(id: completed.id)

        XCTAssertEqual(store.moveUnfinishedTasksToTomorrow(from: monday), 1)
        XCTAssertEqual(store.moveUnfinishedTasksToTomorrow(from: monday), 0)

        let mondayTasks = store.tasks(on: monday)
        XCTAssertEqual(mondayTasks.count, 2)
        XCTAssertNotNil(mondayTasks.first(where: { $0.id == unfinished.id })?.movedToDate)

        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let tomorrowTasks = store.tasks(on: tuesday)
        XCTAssertEqual(tomorrowTasks.count, 1)
        XCTAssertEqual(tomorrowTasks[0].carriedFromTaskID, unfinished.id)
        XCTAssertFalse(tomorrowTasks[0].isCompleted)

        let summary = store.summary(for: monday)
        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.moved, 1)
        XCTAssertEqual(summary.progress, 1)
    }

    func testLayoutSeparatesOverlapsAndReusesLanes() {
        let day = makeDate(year: 2026, month: 8, day: 3)
        let first = DayTask(title: "A", scheduledDay: day, startMinutes: 540, durationMinutes: 180)
        let second = DayTask(title: "B", scheduledDay: day, startMinutes: 600, durationMinutes: 60)
        let third = DayTask(title: "C", scheduledDay: day, startMinutes: 660, durationMinutes: 60)

        let placements = TaskLayoutEngine.placements(for: [third, second, first])
        let firstPlacement = placements.first { $0.task.id == first.id }
        let secondPlacement = placements.first { $0.task.id == second.id }
        let thirdPlacement = placements.first { $0.task.id == third.id }

        XCTAssertEqual(firstPlacement?.laneCount, 2)
        XCTAssertNotEqual(firstPlacement?.lane, secondPlacement?.lane)
        XCTAssertEqual(secondPlacement?.lane, thirdPlacement?.lane)
    }

    func testBackToBackThirtyMinuteBlocksDoNotOverlapVisually() {
        let first = TaskLayoutEngine.timelineFrame(
            startMinutes: 9 * 60,
            durationMinutes: 30,
            hourHeight: 74
        )
        let second = TaskLayoutEngine.timelineFrame(
            startMinutes: 9 * 60 + 30,
            durationMinutes: 30,
            hourHeight: 74
        )

        XCTAssertLessThanOrEqual(first.maxY, second.minY)
        XCTAssertEqual(first.height, 33, accuracy: 0.001)
    }

    func testLateTaskKeepsMinimumDurationInsideDay() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)

        let task = store.addTask(
            title: "Поздняя задача",
            scheduledDay: makeDate(year: 2026, month: 8, day: 3),
            startMinutes: 1_439,
            durationMinutes: 60,
            colorHex: "5B7CFA"
        )

        XCTAssertEqual(task.startMinutes, 1_425)
        XCTAssertEqual(task.durationMinutes, 15)
        XCTAssertEqual(task.endMinutes, 1_440)
    }

    func testSuggestedStartUsesEndOfLastTask() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)

        XCTAssertEqual(store.suggestedStartMinutes(on: day, fallback: 9 * 60 + 7), 9 * 60 + 15)
        store.addTask(title: "Первая", scheduledDay: day, startMinutes: 540, durationMinutes: 60, colorHex: "5B7CFA")
        store.addTask(title: "Последняя", scheduledDay: day, startMinutes: 720, durationMinutes: 75, colorHex: "10B981")

        XCTAssertEqual(store.suggestedStartMinutes(on: day, fallback: 540), 795)
    }

    func testDraggingSnapsToNearestNonOverlappingSlot() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        store.addTask(title: "Занято", scheduledDay: day, startMinutes: 540, durationMinutes: 60, colorHex: "5B7CFA")
        let movable = store.addTask(title: "Двигаем", scheduledDay: day, startMinutes: 660, durationMinutes: 60, colorHex: "10B981")

        let destination = store.moveTask(id: movable.id, to: 570)

        XCTAssertEqual(destination, 600)
        XCTAssertEqual(store.tasks.first(where: { $0.id == movable.id })?.startMinutes, 600)
    }

    func testBottomResizePushesFollowingTask() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let first = store.addTask(title: "Растягиваем", scheduledDay: day, startMinutes: 540, durationMinutes: 60, colorHex: "5B7CFA")
        store.addTask(title: "Следующая", scheduledDay: day, startMinutes: 630, durationMinutes: 60, colorHex: "10B981")

        let duration = store.resizeTask(id: first.id, to: 180)

        XCTAssertEqual(duration, 180)
        XCTAssertEqual(store.tasks.first(where: { $0.id == first.id })?.durationMinutes, 180)
        XCTAssertEqual(store.tasks.first(where: { $0.title == "Следующая" })?.startMinutes, 720)
    }

    func testTopResizeShrinksPreviousTaskBeforeMovingIt() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let previous = store.addTask(title: "Предыдущая", scheduledDay: day, startMinutes: 480, durationMinutes: 60, colorHex: "10B981")
        let task = store.addTask(title: "Растягиваем вверх", scheduledDay: day, startMinutes: 600, durationMinutes: 60, colorHex: "5B7CFA")

        let startMinutes = store.resizeTaskFromTop(id: task.id, to: 510)
        let resized = store.tasks.first(where: { $0.id == task.id })
        let adjustedPrevious = store.tasks.first(where: { $0.id == previous.id })

        XCTAssertEqual(startMinutes, 510)
        XCTAssertEqual(resized?.startMinutes, 510)
        XCTAssertEqual(resized?.durationMinutes, 150)
        XCTAssertEqual(resized?.endMinutes, 660)
        XCTAssertEqual(adjustedPrevious?.startMinutes, 480)
        XCTAssertEqual(adjustedPrevious?.durationMinutes, 30)
        XCTAssertEqual(adjustedPrevious?.endMinutes, 510)
    }

    func testTopResizeMovesPreviousTaskAfterShrinkingItToFifteenMinutes() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let previous = store.addTask(title: "Предыдущая", scheduledDay: day, startMinutes: 540, durationMinutes: 60, colorHex: "10B981")
        let task = store.addTask(title: "Растягиваем вверх", scheduledDay: day, startMinutes: 600, durationMinutes: 60, colorHex: "5B7CFA")

        let startMinutes = store.resizeTaskFromTop(id: task.id, to: 525)
        let adjustedPrevious = store.tasks.first(where: { $0.id == previous.id })

        XCTAssertEqual(startMinutes, 525)
        XCTAssertEqual(adjustedPrevious?.startMinutes, 510)
        XCTAssertEqual(adjustedPrevious?.durationMinutes, 15)
        XCTAssertEqual(adjustedPrevious?.endMinutes, 525)
    }

    func testBottomResizePushesAChainOfTasks() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let first = store.addTask(title: "Первая", scheduledDay: day, startMinutes: 540, durationMinutes: 60, colorHex: "5B7CFA")
        let second = store.addTask(title: "Вторая", scheduledDay: day, startMinutes: 600, durationMinutes: 30, colorHex: "10B981")
        let third = store.addTask(title: "Третья", scheduledDay: day, startMinutes: 630, durationMinutes: 30, colorHex: "8B5CF6")

        let duration = store.resizeTask(id: first.id, to: 120)

        XCTAssertEqual(duration, 120)
        XCTAssertEqual(store.tasks.first(where: { $0.id == second.id })?.startMinutes, 660)
        XCTAssertEqual(store.tasks.first(where: { $0.id == third.id })?.startMinutes, 690)
    }

    func testTopResizePushesAChainOfTasks() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let first = store.addTask(title: "Первая", scheduledDay: day, startMinutes: 510, durationMinutes: 30, colorHex: "5B7CFA")
        let second = store.addTask(title: "Вторая", scheduledDay: day, startMinutes: 540, durationMinutes: 30, colorHex: "10B981")
        let third = store.addTask(title: "Третья", scheduledDay: day, startMinutes: 570, durationMinutes: 60, colorHex: "8B5CF6")

        let startMinutes = store.resizeTaskFromTop(id: third.id, to: 510)

        XCTAssertEqual(startMinutes, 510)
        XCTAssertEqual(store.tasks.first(where: { $0.id == second.id })?.startMinutes, 495)
        XCTAssertEqual(store.tasks.first(where: { $0.id == second.id })?.durationMinutes, 15)
        XCTAssertEqual(store.tasks.first(where: { $0.id == first.id })?.startMinutes, 480)
        XCTAssertEqual(store.tasks.first(where: { $0.id == first.id })?.durationMinutes, 15)
        XCTAssertEqual(store.tasks.first(where: { $0.id == third.id })?.endMinutes, 630)
    }

    func testTopResizeIsLimitedWhenShrunkTaskReachesStartOfDay() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let previous = store.addTask(title: "Предыдущая", scheduledDay: day, startMinutes: 0, durationMinutes: 60, colorHex: "10B981")
        let task = store.addTask(title: "Растягиваем вверх", scheduledDay: day, startMinutes: 60, durationMinutes: 60, colorHex: "5B7CFA")

        let startMinutes = store.resizeTaskFromTop(id: task.id, to: 0)
        let adjustedPrevious = store.tasks.first(where: { $0.id == previous.id })

        XCTAssertEqual(startMinutes, 15)
        XCTAssertEqual(adjustedPrevious?.startMinutes, 0)
        XCTAssertEqual(adjustedPrevious?.durationMinutes, 15)
        XCTAssertEqual(adjustedPrevious?.endMinutes, 15)
    }

    func testBottomResizeIsLimitedWhenPushedChainReachesEndOfDay() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let first = store.addTask(title: "Первая", scheduledDay: day, startMinutes: 1_320, durationMinutes: 30, colorHex: "5B7CFA")
        let second = store.addTask(title: "Вторая", scheduledDay: day, startMinutes: 1_350, durationMinutes: 60, colorHex: "10B981")

        let duration = store.resizeTask(id: first.id, to: 120)

        XCTAssertEqual(duration, 60)
        XCTAssertEqual(store.tasks.first(where: { $0.id == second.id })?.startMinutes, 1_380)
        XCTAssertEqual(store.tasks.first(where: { $0.id == second.id })?.endMinutes, 1_440)
    }

    func testTopResizeCanShortenTaskWhileKeepingEnd() {
        let fixture = makeFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let day = makeDate(year: 2026, month: 8, day: 3)
        let store = TaskStore(fileURL: fixture, calendar: utcCalendar)
        let task = store.addTask(title: "Сокращаем сверху", scheduledDay: day, startMinutes: 600, durationMinutes: 120, colorHex: "5B7CFA")

        let startMinutes = store.resizeTaskFromTop(id: task.id, to: 675)
        let resized = store.tasks.first(where: { $0.id == task.id })

        XCTAssertEqual(startMinutes, 675)
        XCTAssertEqual(resized?.startMinutes, 675)
        XCTAssertEqual(resized?.durationMinutes, 45)
        XCTAssertEqual(resized?.endMinutes, 720)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeFixtureURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylineTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }
}
