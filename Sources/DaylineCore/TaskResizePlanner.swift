import Foundation

public struct TaskTiming: Equatable, Sendable {
    public let startMinutes: Int
    public let durationMinutes: Int

    public var endMinutes: Int { startMinutes + durationMinutes }
}

public struct TaskResizePlan: Equatable, Sendable {
    public let timings: [UUID: TaskTiming]

    public subscript(taskID: UUID) -> TaskTiming? {
        timings[taskID]
    }
}

public enum TaskResizePlanner {
    public static func resizeFromBottom(
        tasks: [DayTask],
        taskID: UUID,
        requestedDurationMinutes: Int
    ) -> TaskResizePlan? {
        guard let selected = tasks.first(where: { $0.id == taskID }), !selected.isMoved else { return nil }
        let maximumDuration = 1_440 - selected.startMinutes
        let requested = min(max(snapToQuarterHour(requestedDurationMinutes), 15), maximumDuration)
        let followers = tasks
            .filter { $0.id != selected.id && $0.startMinutes >= selected.endMinutes }
            .sorted {
                if $0.startMinutes != $1.startMinutes { return $0.startMinutes < $1.startMinutes }
                return $0.endMinutes < $1.endMinutes
            }

        for durationMinutes in stride(from: requested, through: 15, by: -15) {
            if let plan = forwardPlan(
                selected: selected,
                durationMinutes: durationMinutes,
                followers: followers
            ) {
                return plan
            }
        }
        return nil
    }

    public static func resizeFromTop(
        tasks: [DayTask],
        taskID: UUID,
        requestedStartMinutes: Int
    ) -> TaskResizePlan? {
        guard let selected = tasks.first(where: { $0.id == taskID }), !selected.isMoved else { return nil }
        let maximumStart = selected.endMinutes - 15
        let requested = min(max(snapToQuarterHour(requestedStartMinutes), 0), maximumStart)
        let predecessors = tasks
            .filter { $0.id != selected.id && $0.endMinutes <= selected.startMinutes }
            .sorted {
                if $0.endMinutes != $1.endMinutes { return $0.endMinutes > $1.endMinutes }
                return $0.startMinutes > $1.startMinutes
            }

        for startMinutes in stride(from: requested, through: maximumStart, by: 15) {
            if let plan = backwardPlan(
                selected: selected,
                startMinutes: startMinutes,
                predecessors: predecessors
            ) {
                return plan
            }
        }
        return nil
    }

    private static func forwardPlan(
        selected: DayTask,
        durationMinutes: Int,
        followers: [DayTask]
    ) -> TaskResizePlan? {
        var timings = [
            selected.id: TaskTiming(
                startMinutes: selected.startMinutes,
                durationMinutes: durationMinutes
            )
        ]
        var cursor = selected.startMinutes + durationMinutes
        var cascadeStarted = false

        for task in followers {
            guard task.startMinutes < cursor else {
                if cascadeStarted { break }
                continue
            }
            guard !task.isMoved else { return nil }
            let shiftedStart = cursor
            guard shiftedStart + task.durationMinutes <= 1_440 else { return nil }
            timings[task.id] = TaskTiming(
                startMinutes: shiftedStart,
                durationMinutes: task.durationMinutes
            )
            cursor = shiftedStart + task.durationMinutes
            cascadeStarted = true
        }
        return TaskResizePlan(timings: timings)
    }

    private static func backwardPlan(
        selected: DayTask,
        startMinutes: Int,
        predecessors: [DayTask]
    ) -> TaskResizePlan? {
        var timings = [
            selected.id: TaskTiming(
                startMinutes: startMinutes,
                durationMinutes: selected.endMinutes - startMinutes
            )
        ]
        var cursor = startMinutes
        var cascadeStarted = false

        for task in predecessors {
            guard task.endMinutes > cursor else {
                if cascadeStarted { break }
                continue
            }
            guard !task.isMoved else { return nil }
            let shiftedStart = cursor - task.durationMinutes
            guard shiftedStart >= 0 else { return nil }
            timings[task.id] = TaskTiming(
                startMinutes: shiftedStart,
                durationMinutes: task.durationMinutes
            )
            cursor = shiftedStart
            cascadeStarted = true
        }
        return TaskResizePlan(timings: timings)
    }

    private static func snapToQuarterHour(_ minutes: Int) -> Int {
        Int((Double(minutes) / 15).rounded()) * 15
    }
}
