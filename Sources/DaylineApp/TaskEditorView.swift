import SwiftUI

private struct TaskEditorDraft {
    var title: String
    var notes: String
    var scheduledDay: Date
    var startTime: Date
    var durationMinutes: Int
    var colorHex: String
}

struct TaskEditorView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleIsFocused: Bool

    let route: TaskEditorRoute
    @State private var draft: TaskEditorDraft

    private let calendar = Calendar.autoupdatingCurrent
    private let durations = [15, 30, 60, 120, 180]
    private let colors = ["5B7CFA", "8B5CF6", "EC4899", "F97316", "EAB308", "10B981", "0891B2"]

    init(route: TaskEditorRoute) {
        self.route = route
        let calendar = Calendar.autoupdatingCurrent
        switch route {
        case .create(let date, let startMinutes, _):
            let day = calendar.startOfDay(for: date)
            let time = calendar.date(byAdding: .minute, value: startMinutes, to: day) ?? day
            _draft = State(initialValue: TaskEditorDraft(
                title: "",
                notes: "",
                scheduledDay: day,
                startTime: time,
                durationMinutes: 60,
                colorHex: "5B7CFA"
            ))
        case .edit(let task):
            let time = calendar.date(byAdding: .minute, value: task.startMinutes, to: task.scheduledDay) ?? task.scheduledDay
            _draft = State(initialValue: TaskEditorDraft(
                title: task.title,
                notes: task.notes,
                scheduledDay: task.scheduledDay,
                startTime: time,
                durationMinutes: task.durationMinutes,
                colorHex: task.colorHex
            ))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Task" : "New Task")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section {
                    TextField("", text: $draft.title)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .focused($titleIsFocused)
                        .accessibilityLabel("Task name")
                        .accessibilityIdentifier("task-title-field")
                        .frame(maxWidth: .infinity)
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 54)
                        .overlay(alignment: .topLeading) {
                            if draft.notes.isEmpty {
                                Text("Note (optional)")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    taskSectionHeader
                }

                Section("When") {
                    DatePicker("Date", selection: $draft.scheduledDay, displayedComponents: .date)
                    DatePicker("Start", selection: $draft.startTime, displayedComponents: .hourAndMinute)
                    durationSelector
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if case .edit(let task) = route {
                            store.deleteTask(id: task.id)
                            dismiss()
                        }
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier("task-save-button")
            }
            .padding(16)
        }
        .frame(width: 460, height: 500)
        .onAppear { titleIsFocused = true }
    }

    private var taskSectionHeader: some View {
        HStack(spacing: 12) {
            Text("Task")
                .fixedSize()

            GeometryReader { geometry in
                colorSelector(availableWidth: geometry.size.width)
            }
            .frame(height: 25)
        }
    }

    private var durationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")

            HStack(spacing: 6) {
                ForEach(durations, id: \.self) { minutes in
                    let isSelected = draft.durationMinutes == minutes
                    Button {
                        draft.durationMinutes = minutes
                    } label: {
                        Text(durationText(minutes: minutes))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? AppTheme.accent : AppTheme.subtle)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(
                                        isSelected ? AppTheme.accent : AppTheme.line,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(durationText(minutes: minutes))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("task-duration-\(minutes)-button")
                }
            }
        }
    }

    private func colorSelector(availableWidth: CGFloat) -> some View {
        let colorCount = CGFloat(colors.count)
        let minimumSpacing: CGFloat = 4
        let maximumSpacing: CGFloat = 10
        let diameter = min(
            25,
            max(14, (availableWidth - minimumSpacing * (colorCount - 1)) / colorCount)
        )
        let spacing = min(
            maximumSpacing,
            max(0, (availableWidth - diameter * colorCount) / (colorCount - 1))
        )

        return HStack(spacing: spacing) {
            ForEach(colors, id: \.self) { hex in
                Button {
                    draft.colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex).gradient)
                        .frame(width: diameter, height: diameter)
                        .overlay {
                            if draft.colorHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle().stroke(.white.opacity(0.75), lineWidth: draft.colorHex == hex ? 2 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Task color")
                .accessibilityValue(draft.colorHex == hex ? "Selected" : "Not selected")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var isEditing: Bool {
        if case .edit = route { return true }
        return false
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        let components = calendar.dateComponents([.hour, .minute], from: draft.startTime)
        let startMinutes = (components.hour ?? 9) * 60 + (components.minute ?? 0)

        switch route {
        case .create:
            store.addTask(
                title: trimmedTitle,
                notes: draft.notes,
                scheduledDay: draft.scheduledDay,
                startMinutes: startMinutes,
                durationMinutes: draft.durationMinutes,
                colorHex: draft.colorHex
            )
        case .edit(let original):
            var updated = original
            updated.title = trimmedTitle
            updated.notes = draft.notes
            updated.scheduledDay = draft.scheduledDay
            updated.startMinutes = startMinutes
            updated.durationMinutes = draft.durationMinutes
            updated.colorHex = draft.colorHex
            store.updateTask(updated)
        }
        dismiss()
    }
}
