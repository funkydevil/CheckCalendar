import DaylineCore
import SwiftUI

struct TaskBlockView: View {
    let task: DayTask
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
                topResizeHandle(color: color)
                Spacer(minLength: 0)
                bottomResizeHandle(color: color)
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
                Button("Редактировать", systemImage: "pencil", action: onEdit)
                Button(task.isCompleted ? "Вернуть в работу" : "Отметить выполненной", systemImage: statusIcon, action: onToggle)
                Divider()
            }
            Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(subtitle)")
        .accessibilityHint(task.isMoved ? "Архивная запись" : "Перетащите для изменения времени; потяните верхний или нижний край для изменения длительности")
        .accessibilityIdentifier("task-block-\(task.id.uuidString)")
    }

    private func taskContent(color: Color) -> some View {
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

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if isHovering && !task.isMoved {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func topResizeHandle(color: Color) -> some View {
        Color.clear
            .frame(height: 10)
            .overlay {
                Capsule()
                    .fill(color.opacity(isHovering ? 0.72 : 0.32))
                    .frame(width: 34, height: 3)
            }
            .contentShape(Rectangle())
            .gesture(topResizeGesture)
            .disabled(task.isMoved)
            .help("Потяните верхнюю границу, чтобы изменить начало")
            .accessibilityLabel("Изменить начало задачи")
            .accessibilityIdentifier("task-resize-top-handle-\(task.id.uuidString)")
    }

    private func bottomResizeHandle(color: Color) -> some View {
        Color.clear
            .frame(height: 10)
            .overlay {
                Capsule()
                    .fill(color.opacity(isHovering ? 0.72 : 0.32))
                    .frame(width: 34, height: 3)
            }
            .contentShape(Rectangle())
            .gesture(bottomResizeGesture)
            .disabled(task.isMoved)
            .help("Потяните нижнюю границу, чтобы изменить окончание")
            .accessibilityLabel("Изменить окончание задачи")
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
        if task.isMoved { return "Задача перенесена на следующий день" }
        return task.isCompleted ? "Вернуть в работу" : "Отметить выполненной"
    }

    private func statusColor(base: Color) -> Color {
        if task.isMoved { return .orange }
        return task.isCompleted ? .green : base
    }

    private var subtitle: String {
        let time = "\(timeText(minutes: task.startMinutes))–\(timeText(minutes: task.endMinutes))"
        if task.isMoved { return "\(time)  •  перенесено" }
        if task.carriedFromTaskID != nil { return "\(time)  •  со вчера" }
        return "\(time)  •  \(durationText(minutes: task.durationMinutes))"
    }
}
