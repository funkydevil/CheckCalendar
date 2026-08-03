import DaylineCore
import SwiftUI

enum AppSection: Hashable {
    case day
    case history
}

enum TaskEditorRoute: Identifiable {
    case create(date: Date, startMinutes: Int, token: UUID)
    case edit(task: DayTask)

    var id: String {
        switch self {
        case .create(_, _, let token): "create-\(token.uuidString)"
        case .edit(let task): "edit-\(task.id.uuidString)"
        }
    }

    static func new(date: Date, startMinutes: Int = 9 * 60) -> TaskEditorRoute {
        .create(date: date, startMinutes: startMinutes, token: UUID())
    }
}

struct RootView: View {
    @Environment(TaskStore.self) private var store
    @State private var selection: AppSection = .day
    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var editorRoute: TaskEditorRoute?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, selectedDate: $selectedDate)
                .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
        } detail: {
            switch selection {
            case .day:
                DayCalendarView(
                    selectedDate: $selectedDate,
                    onAdd: { minute in editorRoute = .new(date: selectedDate, startMinutes: minute) },
                    onEdit: { editorRoute = .edit(task: $0) }
                )
            case .history:
                HistoryView { date in
                    selectedDate = date
                    selection = .day
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .sheet(item: $editorRoute) { route in
            TaskEditorView(route: route)
                .environment(store)
        }
        .alert(
            "Ошибка хранилища",
            isPresented: Binding(
                get: { store.persistenceError != nil },
                set: { isPresented in
                    if !isPresented { store.clearPersistenceError() }
                }
            )
        ) {
            Button("Понятно") { store.clearPersistenceError() }
        } message: {
            Text(store.persistenceError ?? "Неизвестная ошибка")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDaylineTask)) { _ in
            selection = .day
            editorRoute = .new(date: selectedDate)
        }
    }
}

private struct SidebarView: View {
    @Binding var selection: AppSection
    @Binding var selectedDate: Date
    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.accent.gradient)
                    Image(systemName: "checkmark.square.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("День за днём")
                        .font(.headline)
                    Text("Планируй и завершай")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            List(selection: $selection) {
                Section("Рабочее пространство") {
                    Label("Мой день", systemImage: "calendar.day.timeline.left")
                        .tag(AppSection.day)
                    Label("История", systemImage: "clock.arrow.circlepath")
                        .tag(AppSection.history)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 10) {
                Text("Выбранный день")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                DatePicker(
                    "Дата",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .accessibilityLabel("Выбранная дата")

                Button {
                    selectedDate = calendar.startOfDay(for: .now)
                    selection = .day
                } label: {
                    Label("Вернуться к сегодня", systemImage: "location.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
            }
            .padding(16)
            .background(AppTheme.subtle)
        }
        .background(AppTheme.sidebar)
    }
}
