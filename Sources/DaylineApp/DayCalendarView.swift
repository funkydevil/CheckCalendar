import SwiftUI

struct DayCalendarView: View {
    @Environment(TaskStore.self) private var store
    @Binding var selectedDate: Date
    let onAdd: (Int) -> Void
    let onEdit: (DayTask) -> Void

    @State private var showMoveConfirmation = false
    @State private var showDatePicker = false
    @State private var showHistory = false
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
        .alert("Move to Tomorrow?", isPresented: $showMoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move \(unfinishedCount)") { moveUnfinished() }
        } message: {
            Text("Unfinished tasks will remain in this day's history and appear tomorrow as new items.")
        }
    }

    private var header: some View {
        VStack(spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 9) {
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Choose date")
                    .accessibilityLabel("Choose date")
                    .accessibilityIdentifier("calendar-icon-button")

                    VStack(alignment: .leading, spacing: 1) {
                        Button {
                            showDatePicker.toggle()
                        } label: {
                            Text(selectedDate.headerDay)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .help("Choose date")
                        .accessibilityLabel("Choose date: \(selectedDate.headerDay)")
                        .accessibilityIdentifier("date-popover-button")
                        .popover(
                            isPresented: $showDatePicker,
                            attachmentAnchor: .rect(.bounds),
                            arrowEdge: .top
                        ) {
                            datePickerPopover
                                .presentationCompactAdaptation(.popover)
                        }

                        Text(summaryLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .layoutPriority(1)

                if let movedMessage {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.green)
                        .help(movedMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 3) {
                    Button { changeDay(by: -1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Previous day")

                    Button {
                        selectedDate = calendar.startOfDay(for: .now)
                        movedMessage = nil
                    } label: {
                        Image(systemName: "scope")
                    }
                    .disabled(calendar.isDateInToday(selectedDate))
                    .help("Today")
                    .accessibilityLabel("Today")

                    Button { changeDay(by: 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("Next day")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.system(size: 15, weight: .semibold))

                Button {
                    showHistory.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.system(size: 15, weight: .semibold))
                .help("History")
                .accessibilityLabel("History")
                .accessibilityIdentifier("history-popover-button")
                .popover(isPresented: $showHistory, arrowEdge: .top) {
                    HistoryView { date in
                        selectedDate = calendar.startOfDay(for: date)
                        movedMessage = nil
                        showHistory = false
                    }
                    .frame(width: 420, height: 480)
                    .presentationCompactAdaptation(.popover)
                }

                Button {
                    showMoveConfirmation = true
                } label: {
                    Image(systemName: "arrow.right.to.line.compact")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .font(.system(size: 15, weight: .semibold))
                .disabled(unfinishedCount == 0)
                .help("Move all unfinished tasks to tomorrow")
                .accessibilityLabel("Move to Tomorrow")
                .accessibilityIdentifier("move-unfinished-button")

                Button {
                    onAdd(defaultStartMinute)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 18, height: 18, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.trailing, 10)
                .accessibilityLabel("New Task")
                .accessibilityIdentifier("add-task-button")
            }

            ProgressView(value: summary.progress)
                .tint(summary.remaining == 0 && summary.total > 0 ? .green : AppTheme.accent)
                .accessibilityLabel("Day progress")
                .accessibilityValue("\(summary.resolved) of \(summary.total)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var datePickerPopover: some View {
        VStack(spacing: 10) {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDate },
                    set: { date in
                        selectedDate = calendar.startOfDay(for: date)
                        movedMessage = nil
                        showDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .accessibilityIdentifier("calendar-date-picker")

            Divider()

            Button("Today") {
                selectedDate = calendar.startOfDay(for: .now)
                movedMessage = nil
                showDatePicker = false
            }
            .buttonStyle(.bordered)
            .disabled(calendar.isDateInToday(selectedDate))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(width: 170)
    }

    private var summaryLine: String {
        guard summary.total > 0 else { return "Open day — add your first task" }
        var parts = ["\(summary.completed) of \(summary.total) completed"]
        if summary.moved > 0 { parts.append("\(summary.moved) moved") }
        parts.append("\(durationText(minutes: summary.scheduledMinutes)) planned")
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
            movedMessage = count == 1 ? "1 task moved" : "\(count) tasks moved"
        }
    }
}

private struct TimelineViewContent: View {
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
    @State private var resizePlan: TaskResizePlan?

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
                    proxy.scrollTo(calendar.isDateInToday(date) ? currentHourAnchor : 7, anchor: .top)
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
        let originalTasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let placements = TaskLayoutEngine.placements(for: renderedTasks)
        let contentX = labelWidth + 14
        let availableWidth = max(totalWidth - contentX - 24, 240)

        ForEach(placements) { placement in
            let originalTask = originalTasksByID[placement.task.id] ?? placement.task
            let spacing: CGFloat = 6
            let laneWidth = (availableWidth - spacing * CGFloat(placement.laneCount - 1)) / CGFloat(placement.laneCount)
            let x = contentX + CGFloat(placement.lane) * (laneWidth + spacing)
            let timelineFrame = TaskLayoutEngine.timelineFrame(
                startMinutes: placement.task.startMinutes,
                durationMinutes: placement.task.durationMinutes,
                hourHeight: Double(hourHeight)
            )
            let y = CGFloat(timelineFrame.minY)
            let height = min(CGFloat(timelineFrame.height), hourHeight * 24 - y - 2)
            let moveRange = (2 - y)...(hourHeight * 24 - height - 2 - y)

            TaskBlockView(
                task: placement.task,
                isCompact: placement.task.durationMinutes <= 30,
                moveRange: moveRange,
                onToggle: { onToggle(placement.task.id) },
                onEdit: { onEdit(originalTask) },
                onDelete: { onDelete(placement.task.id) },
                onMoveEnded: { translation in
                    let requested = originalTask.startMinutes + snappedMinuteDelta(for: translation)
                    onMove(placement.task.id, requested)
                },
                onTopResizeChanged: { translation in
                    let requested = originalTask.startMinutes + snappedMinuteDelta(for: translation)
                    updateTopResizePreview(for: placement.task.id, requestedStartMinutes: requested)
                },
                onTopResizeEnded: { translation in
                    let requested = originalTask.startMinutes + snappedMinuteDelta(for: translation)
                    clearResizePreview()
                    onResizeFromTop(placement.task.id, requested)
                },
                onBottomResizeChanged: { translation in
                    let requested = originalTask.durationMinutes + snappedMinuteDelta(for: translation)
                    updateBottomResizePreview(for: placement.task.id, requestedDurationMinutes: requested)
                },
                onBottomResizeEnded: { translation in
                    let requested = originalTask.durationMinutes + snappedMinuteDelta(for: translation)
                    clearResizePreview()
                    onResize(placement.task.id, requested)
                }
            )
            .frame(width: laneWidth, height: height)
            .offset(x: x, y: y)
            .zIndex(resizingTaskID == placement.task.id ? 10 : 1)
        }
    }

    private var renderedTasks: [DayTask] {
        tasks.map { task in
            guard let timing = resizePlan?[task.id] else { return task }
            var rendered = task
            rendered.startMinutes = timing.startMinutes
            rendered.durationMinutes = timing.durationMinutes
            return rendered
        }
    }

    private func snappedMinuteDelta(for translation: CGFloat) -> Int {
        let rawMinutes = translation / hourHeight * 60
        return Int((rawMinutes / 15).rounded()) * 15
    }

    private func clearResizePreview() {
        resizingTaskID = nil
        resizePlan = nil
    }

    private func updateTopResizePreview(for taskID: UUID, requestedStartMinutes: Int) {
        let plan = TaskResizePlanner.resizeFromTop(
            tasks: tasks,
            taskID: taskID,
            requestedStartMinutes: requestedStartMinutes
        )
        resizingTaskID = taskID
        if resizePlan != plan { resizePlan = plan }
    }

    private func updateBottomResizePreview(for taskID: UUID, requestedDurationMinutes: Int) {
        let plan = TaskResizePlanner.resizeFromBottom(
            tasks: tasks,
            taskID: taskID,
            requestedDurationMinutes: requestedDurationMinutes
        )
        resizingTaskID = taskID
        if resizePlan != plan { resizePlan = plan }
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
