import DaylineCore
import SwiftUI

struct HistoryView: View {
    @Environment(TaskStore.self) private var store
    let onOpenDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("История")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Все запланированные дни и их результат")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.history.count) \(dayWord(store.history.count))")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.subtle, in: Capsule())
            }
            .padding(24)
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
                    LazyVStack(spacing: 12) {
                        ForEach(store.history) { summary in
                            HistoryCard(summary: summary) {
                                onOpenDay(summary.date)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
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
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.line, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: summary.progress)
                        .stroke(
                            summary.remaining == 0 ? Color.green : AppTheme.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(summary.progress * 100))%")
                        .font(.caption2.bold().monospacedDigit())
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.date.russianShortDay.capitalizingFirstLetter)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label("\(summary.completed) выполнено", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if summary.moved > 0 {
                            Label("\(summary.moved) перенесено", systemImage: "arrow.right.circle.fill")
                                .foregroundStyle(.orange)
                        }
                        if summary.remaining > 0 {
                            Label("\(summary.remaining) осталось", systemImage: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(durationText(minutes: summary.scheduledMinutes))
                        .font(.callout.weight(.semibold))
                    Text("\(summary.total) задач")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.date.russianShortDay), \(summary.completed) из \(summary.total) выполнено")
    }
}
