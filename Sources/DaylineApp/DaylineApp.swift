import DaylineCore
import SwiftUI

@main
struct DaylineApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        WindowGroup("День за днём") {
            RootView()
                .environment(store)
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1_150, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новая задача") {
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
