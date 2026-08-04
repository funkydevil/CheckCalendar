# Dayline

A native calendar checklist for macOS. Tasks appear on a 24-hour timeline, their height reflects their duration, and overlapping tasks are automatically arranged into columns.

## Features

- Tasks with a start time, duration, note, and color.
- Mouse-driven rescheduling in 15-minute increments with overlap protection.
- Duration editing by dragging either the top or bottom edge of a task.
- Completion toggles directly in the calendar.
- Daily history with progress summaries.
- Move all unfinished tasks to tomorrow without losing the original history entry.
- Local storage in `Application Support/Dayline/tasks.json`.
- Create a task by double-clicking the timeline or pressing `⌘N`.
- Tasks created with the toolbar button automatically start after the day's final task.

## Open and Run

```bash
open Dayline.xcodeproj
```

Choose the `Dayline` scheme in Xcode and press `⌘R`.

## App Store Archive

1. Select a development team in the Dayline target's Signing & Capabilities tab.
2. Replace `com.funkydevil.Dayline` with the bundle identifier registered in App Store Connect.
3. Choose **Product → Archive**, then **Distribute App → App Store Connect**.

## Tests

```bash
xcodebuild -project Dayline.xcodeproj -scheme Dayline -destination 'platform=macOS' test
```
