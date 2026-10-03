//
//  CourseCardView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseCardView: View {

    let course: Course
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Label(course.instructor, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressSummaryView(
                        progress: course.progress,
                        detailText: "\(course.lessonCount) lessons"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                Label("Continue", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("Continue \(course.title)")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    CourseCardView(
        course: Course(id: 1, title: "Python Programming", instructor: "John Smith", progress: 65, lessonCount: 20),
        onOpen: {}
    )
    .padding()
}
