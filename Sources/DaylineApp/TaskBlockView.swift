import DaylineCore
import SwiftUI

struct TaskBlockView: View {
    let task: DayTask
    let isCompact: Bool
    let moveRange: ClosedRange<CGFloat>
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveEnded: (CGFloat) -> Void
    let onTopResizeChanged: (CGFloat) -> Void
    let onTopResizeEnded: (CGFloat) -> Void
    let onBottomResizeChanged: (CGFloat) -> Void
    let onBottomResizeEnded: (CGFloat) -> Void

    @State private var isHovering = false
    @State private var didDrag = false
    @State private var isDragging = false
    @State private var moveTranslation: CGFloat = 0

    var body: some View {
        let color = Color(hex: task.colorHex)
        ZStack {
            taskContent(color: color)
                .contentShape(Rectangle())
                .simultaneousGesture(moveGesture)

            VStack(spacing: 0) {
                topResizeHandle
                Spacer(minLength: 0)
                bottomResizeHandle
            }
        }
        .background {
            blockBackground(color: color)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(task.isCompleted || task.isMoved ? 0.72 : 1)
        .offset(y: clampedMoveTranslation)
        .shadow(color: .black.opacity(isDragging ? 0.14 : 0), radius: 8, y: 4)
        .scaleEffect(isDragging ? 1.006 : 1)
        .zIndex(isDragging ? 10 : 0)
        .onTapGesture {
            if !task.isMoved && !didDrag { onEdit() }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if !task.isMoved {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: statusIcon, action: onToggle)
                Divider()
            }
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(subtitle)")
        .accessibilityHint(task.isMoved ? "Archived task" : "Drag to reschedule; drag the top or bottom edge to change duration")
        .accessibilityIdentifier("task-block-\(task.id.uuidString)")
    }

    @ViewBuilder
    private func taskContent(color: Color) -> some View {
        if isCompact {
            compactTaskContent(color: color)
        } else {
            regularTaskContent(color: color)
        }
    }

    private func compactTaskContent(color: Color) -> some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: statusIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor(base: color))
            }
            .buttonStyle(.plain)
            .disabled(task.isMoved)
            .help(toggleHelp)

            Text(task.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .strikethrough(task.isCompleted)

            Spacer(minLength: 2)

            Text("\(timeText(minutes: task.startMinutes))–\(timeText(minutes: task.endMinutes))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func regularTaskContent(color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Button(action: onToggle) {
                Image(systemName: statusIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(statusColor(base: color))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(task.isMoved)
            .help(toggleHelp)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)

                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !task.notes.isEmpty && task.durationMinutes >= 90 {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var topResizeHandle: some View {
        Color.clear
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(topResizeGesture)
            .disabled(task.isMoved)
            .help("Drag the top edge to change the start time")
            .accessibilityLabel("Change task start time")
            .accessibilityIdentifier("task-resize-top-handle-\(task.id.uuidString)")
    }

    private var bottomResizeHandle: some View {
        Color.clear
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(bottomResizeGesture)
            .disabled(task.isMoved)
            .help("Drag the bottom edge to change the end time")
            .accessibilityLabel("Change task end time")
            .accessibilityIdentifier("task-resize-bottom-handle-\(task.id.uuidString)")
    }

    private func blockBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(task.isCompleted || task.isMoved ? 0.09 : 0.16))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(color.opacity(task.isMoved ? 0.35 : 0.9))
                .frame(width: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color.opacity(isHovering ? 0.55 : 0.18), lineWidth: 1)
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                guard !task.isMoved else { return }
                didDrag = true
                isDragging = true
                moveTranslation = value.translation.height
            }
            .onEnded { value in
                guard !task.isMoved else { return }
                onMoveEnded(value.translation.height)
                moveTranslation = 0
                isDragging = false
                resetDragFlag()
            }
    }

    private var topResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                guard !task.isMoved else { return }
                didDrag = true
                onTopResizeChanged(value.translation.height)
            }
            .onEnded { value in
                guard !task.isMoved else { return }
                onTopResizeEnded(value.translation.height)
                resetDragFlag()
            }
    }

    private var bottomResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                guard !task.isMoved else { return }
                didDrag = true
                onBottomResizeChanged(value.translation.height)
            }
            .onEnded { value in
                guard !task.isMoved else { return }
                onBottomResizeEnded(value.translation.height)
                resetDragFlag()
            }
    }

    private func resetDragFlag() {
        DispatchQueue.main.async {
            didDrag = false
        }
    }

    private var clampedMoveTranslation: CGFloat {
        min(max(moveTranslation, moveRange.lowerBound), moveRange.upperBound)
    }

    private var statusIcon: String {
        if task.isMoved { return "arrow.right.circle.fill" }
        return task.isCompleted ? "checkmark.circle.fill" : "circle"
    }

    private var toggleHelp: String {
        if task.isMoved { return "Task moved to the next day" }
        return task.isCompleted ? "Mark Incomplete" : "Mark Complete"
    }

    private func statusColor(base: Color) -> Color {
        if task.isMoved { return .orange }
        return task.isCompleted ? .green : base
    }

    private var subtitle: String {
        let time = "\(timeText(minutes: task.startMinutes))–\(timeText(minutes: task.endMinutes))"
        if task.isMoved { return "\(time)  •  moved" }
        if task.carriedFromTaskID != nil { return "\(time)  •  from yesterday" }
        return "\(time)  •  \(durationText(minutes: task.durationMinutes))"
    }
}
