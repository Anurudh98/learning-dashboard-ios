//
//  LessonRowView.swift
//  LearningDashboard
//

import SwiftUI

struct LessonRowView: View {

    let lesson: Lesson
    let isCompleting: Bool
    let isActionDisabled: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: lesson.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(lesson.isCompleted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.body)
                Text(lesson.isCompleted ? "✓ Completed" : "○ Pending")
                    .font(.caption)
                    .foregroundStyle(lesson.isCompleted ? Color.green : Color.secondary)
            }

            Spacer(minLength: 8)

            if isCompleting {
                ProgressView()
            } else if !lesson.isCompleted {
                Button("Mark Done", action: onComplete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isActionDisabled)
                    .accessibilityLabel("Mark \(lesson.title) as completed")
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy, value: lesson.isCompleted)
    }
}

#Preview {
    List {
        LessonRowView(lesson: Lesson(id: 1, title: "Introduction", isCompleted: true), isCompleting: false, isActionDisabled: false) {}
        LessonRowView(lesson: Lesson(id: 2, title: "Functions", isCompleted: false), isCompleting: false, isActionDisabled: false) {}
    }
}
