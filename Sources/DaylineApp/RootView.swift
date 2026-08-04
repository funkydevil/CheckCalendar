import SwiftUI

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
    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var editorRoute: TaskEditorRoute?

    var body: some View {
        DayCalendarView(
            selectedDate: $selectedDate,
            onAdd: { minute in editorRoute = .new(date: selectedDate, startMinutes: minute) },
            onEdit: { editorRoute = .edit(task: $0) }
        )
        .tint(AppTheme.accent)
        .sheet(item: $editorRoute) { route in
            TaskEditorView(route: route)
                .environment(store)
        }
        .alert(
            "Storage Error",
            isPresented: Binding(
                get: { store.persistenceError != nil },
                set: { isPresented in
                    if !isPresented { store.clearPersistenceError() }
                }
            )
        ) {
            Button("OK") { store.clearPersistenceError() }
        } message: {
            Text(store.persistenceError ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDaylineTask)) { _ in
            editorRoute = .new(date: selectedDate)
        }
    }
}
