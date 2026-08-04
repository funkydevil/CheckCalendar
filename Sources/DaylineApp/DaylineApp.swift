import DaylineCore
import SwiftUI

@main
struct DaylineApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        WindowGroup("Dayline") {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 820, height: 620)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .newDaylineTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newDaylineTask = Notification.Name("Dayline.newTask")
}
