import DaylineCore
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
    private let durations = [15, 30, 45, 60, 90, 120, 180, 240, 360]
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
                Text(isEditing ? "Редактировать задачу" : "Новая задача")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Задача") {
                    TextField("", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleIsFocused)
                        .accessibilityLabel("Название задачи")
                        .accessibilityIdentifier("task-title-field")
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 54)
                        .overlay(alignment: .topLeading) {
                            if draft.notes.isEmpty {
                                Text("Заметка (необязательно)")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Когда") {
                    DatePicker("День", selection: $draft.scheduledDay, displayedComponents: .date)
                    DatePicker("Начало", selection: $draft.startTime, displayedComponents: .hourAndMinute)
                    Picker("Длительность", selection: $draft.durationMinutes) {
                        ForEach(durations, id: \.self) { minutes in
                            Text(durationText(minutes: minutes)).tag(minutes)
                        }
                    }
                }

                Section("Цвет") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                draft.colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex).gradient)
                                    .frame(width: 25, height: 25)
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
                            .accessibilityLabel("Цвет задачи")
                            .accessibilityValue(draft.colorHex == hex ? "Выбран" : "Не выбран")
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if isEditing {
                    Button("Удалить", role: .destructive) {
                        if case .edit(let task) = route {
                            store.deleteTask(id: task.id)
                            dismiss()
                        }
                    }
                }
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Сохранить" : "Добавить") { save() }
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
