import DaylineCore
import SwiftUI

struct DayCalendarView: View {
    @Environment(TaskStore.self) private var store
    @Binding var selectedDate: Date
    let onAdd: (Int) -> Void
    let onEdit: (DayTask) -> Void

    @State private var showMoveConfirmation = false
    @State private var movedMessage: String?
    private let calendar = Calendar.autoupdatingCurrent

    private var tasks: [DayTask] { store.tasks(on: selectedDate) }
    private var summary: DaySummary { store.summary(for: selectedDate) }
    private var unfinishedCount: Int { store.unfinishedCount(on: selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TimelineViewContent(
                date: selectedDate,
                tasks: tasks,
                onAdd: onAdd,
                onEdit: onEdit,
                onToggle: { id in
                    withAnimation(.snappy(duration: 0.25)) {
                        store.toggleCompletion(id: id)
                    }
                },
                onDelete: store.deleteTask,
                onMove: { id, startMinutes in
                    _ = store.moveTask(id: id, to: startMinutes)
                },
                onResize: { id, durationMinutes in
                    _ = store.resizeTask(id: id, to: durationMinutes)
                },
                onResizeFromTop: { id, startMinutes in
                    _ = store.resizeTaskFromTop(id: id, to: startMinutes)
                }
            )
        }
        .background(AppTheme.canvas)
        .alert("Перенести на завтра?", isPresented: $showMoveConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Перенести \(unfinishedCount)") { moveUnfinished() }
        } message: {
            Text("Невыполненные задачи останутся в истории этого дня и появятся завтра как новые пункты.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(selectedDate.russianDayTitle.capitalizingFirstLetter)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        if calendar.isDateInToday(selectedDate) {
                            Text("Сегодня")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent.opacity(0.13), in: Capsule())
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    Text(summaryLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let movedMessage {
                    Label(movedMessage, systemImage: "arrow.right.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 4) {
                    Button { changeDay(by: -1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Предыдущий день")
                    Button("Сегодня") {
                        selectedDate = calendar.startOfDay(for: .now)
                    }
                    .disabled(calendar.isDateInToday(selectedDate))
                    Button { changeDay(by: 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("Следующий день")
                }
                .buttonStyle(.bordered)

                Button {
                    showMoveConfirmation = true
                } label: {
                    Label("На завтра", systemImage: "arrow.right.to.line.compact")
                }
                .buttonStyle(.bordered)
                .disabled(unfinishedCount == 0)
                .help("Перенести все невыполненные задачи")
                .accessibilityIdentifier("move-unfinished-button")

                Button {
                    onAdd(defaultStartMinute)
                } label: {
                    Label("Новая задача", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .accessibilityIdentifier("add-task-button")
            }

            ProgressView(value: summary.progress)
                .tint(summary.remaining == 0 && summary.total > 0 ? .green : AppTheme.accent)
                .accessibilityLabel("Прогресс дня")
                .accessibilityValue("\(summary.resolved) из \(summary.total)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private var summaryLine: String {
        guard summary.total > 0 else { return "Свободный день — добавьте первую задачу" }
        var parts = ["\(summary.completed) из \(summary.total) выполнено"]
        if summary.moved > 0 { parts.append("\(summary.moved) перенесено") }
        parts.append("\(durationText(minutes: summary.scheduledMinutes)) в плане")
        return parts.joined(separator: "  •  ")
    }

    private var defaultStartMinute: Int {
        let fallback: Int
        if calendar.isDateInToday(selectedDate) {
            let components = calendar.dateComponents([.hour, .minute], from: .now)
            fallback = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        } else {
            fallback = 9 * 60
        }
        return store.suggestedStartMinutes(on: selectedDate, fallback: fallback)
    }

    private func changeDay(by amount: Int) {
        guard let date = calendar.date(byAdding: .day, value: amount, to: selectedDate) else { return }
        selectedDate = calendar.startOfDay(for: date)
        movedMessage = nil
    }

    private func moveUnfinished() {
        let count = store.moveUnfinishedTasksToTomorrow(from: selectedDate)
        withAnimation(.snappy) {
            movedMessage = count == 1 ? "1 задача перенесена" : "\(count) задач перенесено"
        }
    }
}

private struct TimelineViewContent: View {
    private enum ResizeEdge {
        case top
        case bottom
    }

    let date: Date
    let tasks: [DayTask]
    let onAdd: (Int) -> Void
    let onEdit: (DayTask) -> Void
    let onToggle: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onResize: (UUID, Int) -> Void
    let onResizeFromTop: (UUID, Int) -> Void

    @State private var resizingTaskID: UUID?
    @State private var resizingEdge: ResizeEdge?
    @State private var resizeTranslation: CGFloat = 0

    private let hourHeight: CGFloat = 74
    private let labelWidth: CGFloat = 64
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        timelineGrid
                        taskBlocks(totalWidth: geometry.size.width)
                        currentTimeLine(totalWidth: geometry.size.width)
                    }
                    .frame(width: geometry.size.width, height: hourHeight * 24)
                }
                .onAppear {
                    proxy.scrollTo(7, anchor: .top)
                }
                .onChange(of: date) {
                    proxy.scrollTo(calendar.isDateInToday(date) ? currentHourAnchor : 7, anchor: .top)
                }
            }
        }
    }

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 10) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                        .offset(y: -7)
                    Rectangle()
                        .fill(AppTheme.line)
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .padding(.trailing, 18)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, coordinateSpace: .local) { point in
            let minute = min(max(Int(point.y / hourHeight * 60), 0), 1_439)
            onAdd((minute / 15) * 15)
        }
    }

    @ViewBuilder
    private func taskBlocks(totalWidth: CGFloat) -> some View {
        let placements = TaskLayoutEngine.placements(for: tasks)
        let contentX = labelWidth + 14
        let availableWidth = max(totalWidth - contentX - 24, 240)

        ForEach(placements) { placement in
            let spacing: CGFloat = 6
            let laneWidth = (availableWidth - spacing * CGFloat(placement.laneCount - 1)) / CGFloat(placement.laneCount)
            let x = contentX + CGFloat(placement.lane) * (laneWidth + spacing)
            let previewStart = previewStartMinutes(for: placement.task)
            let previewDuration = previewDurationMinutes(for: placement.task)
            let y = CGFloat(previewStart) / 60 * hourHeight + 3
            let rawHeight = CGFloat(previewDuration) / 60 * hourHeight - 6
            let height = min(max(rawHeight, 38), hourHeight * 24 - y - 3)
            let moveRange = (3 - y)...(hourHeight * 24 - height - 3 - y)

            TaskBlockView(
                task: placement.task,
                moveRange: moveRange,
                onToggle: { onToggle(placement.task.id) },
                onEdit: { onEdit(placement.task) },
                onDelete: { onDelete(placement.task.id) },
                onMoveEnded: { translation in
                    let requested = placement.task.startMinutes + snappedMinuteDelta(for: translation)
                    onMove(placement.task.id, requested)
                },
                onTopResizeChanged: { translation in
                    updateResizePreview(for: placement.task.id, edge: .top, translation: translation)
                },
                onTopResizeEnded: { translation in
                    let requested = placement.task.startMinutes + snappedMinuteDelta(for: translation)
                    clearResizePreview()
                    onResizeFromTop(placement.task.id, requested)
                },
                onBottomResizeChanged: { translation in
                    updateResizePreview(for: placement.task.id, edge: .bottom, translation: translation)
                },
                onBottomResizeEnded: { translation in
                    let requested = placement.task.durationMinutes + snappedMinuteDelta(for: translation)
                    clearResizePreview()
                    onResize(placement.task.id, requested)
                }
            )
            .frame(width: laneWidth, height: height)
            .offset(x: x, y: y)
            .zIndex(resizingTaskID == placement.task.id ? 10 : 1)
        }
    }

    private func previewStartMinutes(for task: DayTask) -> Int {
        guard resizingTaskID == task.id, resizingEdge == .top else { return task.startMinutes }
        return min(
            max(task.startMinutes + snappedMinuteDelta(for: resizeTranslation), 0),
            task.endMinutes - 15
        )
    }

    private func previewDurationMinutes(for task: DayTask) -> Int {
        guard resizingTaskID == task.id else { return task.durationMinutes }
        switch resizingEdge {
        case .top:
            return task.endMinutes - previewStartMinutes(for: task)
        case .bottom:
            let maximumDuration = 1_440 - task.startMinutes
            return min(max(task.durationMinutes + snappedMinuteDelta(for: resizeTranslation), 15), maximumDuration)
        case nil:
            return task.durationMinutes
        }
    }

    private func snappedMinuteDelta(for translation: CGFloat) -> Int {
        let rawMinutes = translation / hourHeight * 60
        return Int((rawMinutes / 15).rounded()) * 15
    }

    private func clearResizePreview() {
        resizingTaskID = nil
        resizingEdge = nil
        resizeTranslation = 0
    }

    private func updateResizePreview(for taskID: UUID, edge: ResizeEdge, translation: CGFloat) {
        resizingTaskID = taskID
        resizingEdge = edge
        resizeTranslation = translation
    }

    @ViewBuilder
    private func currentTimeLine(totalWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if calendar.isDate(context.date, inSameDayAs: date) {
                let components = calendar.dateComponents([.hour, .minute], from: context.date)
                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                let y = CGFloat(minutes) / 60 * hourHeight
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Rectangle().fill(.red).frame(height: 1)
                }
                .frame(width: max(totalWidth - labelWidth - 14, 0))
                .offset(x: labelWidth + 10, y: y - 4)
                .accessibilityHidden(true)
            }
        }
    }

    private var currentHourAnchor: Int {
        max((calendar.component(.hour, from: .now) - 1), 0)
    }
}
