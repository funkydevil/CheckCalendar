import DaylineCore
import SwiftUI

struct HistoryView: View {
    @Environment(TaskStore.self) private var store
    let onOpenDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("История")
                    .font(.title2.bold())
                Spacer()
                Text("\(store.history.count) \(dayWord(store.history.count))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.subtle, in: Capsule())
            }
            .padding(16)
            .background(.bar)

            Divider()

            if store.history.isEmpty {
                ContentUnavailableView {
                    Label("История пока пуста", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Добавьте задачу в календарь — здесь появится сводка дня.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.history) { summary in
                            HistoryCard(summary: summary) {
                                onOpenDay(summary.date)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(AppTheme.canvas)
    }

    private func dayWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "дней" }
        if last == 1 { return "день" }
        if (2...4).contains(last) { return "дня" }
        return "дней"
    }
}

private struct HistoryCard: View {
    let summary: DaySummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.line, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: summary.progress)
                        .stroke(
                            summary.remaining == 0 ? Color.green : AppTheme.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(summary.progress * 100))%")
                        .font(.caption2.bold().monospacedDigit())
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.date.russianShortDay.capitalizingFirstLetter)
                        .font(.headline)
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(durationText(minutes: summary.scheduledMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.date.russianShortDay), \(summary.completed) из \(summary.total) выполнено")
    }

    private var detailLine: String {
        var parts = ["\(summary.completed)/\(summary.total) выполнено"]
        if summary.moved > 0 { parts.append("\(summary.moved) перенесено") }
        if summary.remaining > 0 { parts.append("\(summary.remaining) осталось") }
        return parts.joined(separator: "  •  ")
    }
}
