import Foundation

public struct TaskPlacement: Identifiable, Hashable, Sendable {
    public let task: DayTask
    public let lane: Int
    public let laneCount: Int

    public var id: UUID { task.id }
}

public struct TimelineBlockFrame: Equatable, Sendable {
    public let minY: Double
    public let height: Double

    public var maxY: Double { minY + height }
}

public enum TaskLayoutEngine {
    public static func timelineFrame(
        startMinutes: Int,
        durationMinutes: Int,
        hourHeight: Double,
        verticalInset: Double = 2
    ) -> TimelineBlockFrame {
        let minY = Double(startMinutes) / 60 * hourHeight + verticalInset
        let durationHeight = Double(durationMinutes) / 60 * hourHeight
        return TimelineBlockFrame(
            minY: minY,
            height: max(durationHeight - verticalInset * 2, 1)
        )
    }

    public static func placements(for tasks: [DayTask]) -> [TaskPlacement] {
        let sorted = tasks.sorted {
            if $0.startMinutes != $1.startMinutes { return $0.startMinutes < $1.startMinutes }
            if $0.endMinutes != $1.endMinutes { return $0.endMinutes < $1.endMinutes }
            return $0.id.uuidString < $1.id.uuidString
        }

        var placements: [TaskPlacement] = []
        var cluster: [(task: DayTask, lane: Int)] = []
        var laneEnds: [Int] = []
        var clusterEnd = -1

        func appendCluster() {
            let laneCount = max(laneEnds.count, 1)
            placements.append(contentsOf: cluster.map {
                TaskPlacement(task: $0.task, lane: $0.lane, laneCount: laneCount)
            })
        }

        for task in sorted {
            if !cluster.isEmpty, task.startMinutes >= clusterEnd {
                appendCluster()
                cluster.removeAll(keepingCapacity: true)
                laneEnds.removeAll(keepingCapacity: true)
                clusterEnd = -1
            }

            let availableLane = laneEnds.firstIndex(where: { $0 <= task.startMinutes })
            let lane: Int
            if let availableLane {
                lane = availableLane
                laneEnds[lane] = task.endMinutes
            } else {
                lane = laneEnds.count
                laneEnds.append(task.endMinutes)
            }

            cluster.append((task, lane))
            clusterEnd = max(clusterEnd, task.endMinutes)
        }

        if !cluster.isEmpty { appendCluster() }
        return placements
    }
}
