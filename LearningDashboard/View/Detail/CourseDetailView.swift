//
//  CourseDetailView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseDetailView: View {

    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var viewModel: CourseDetailViewModel

    init(viewModel: @autoclosure @escaping () -> CourseDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner(dataSource: viewModel.dataSource)

            if viewModel.hasUnsyncedChanges {
                StatusBanner(
                    message: "Progress saved on this device. It will sync when you're back online.",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .blue
                )
            }

            content
        }
        .navigationTitle(viewModel.course.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: networkMonitor.isOnline) { _, isOnline in
            guard isOnline else { return }
            Task { await viewModel.onConnectivityRestored() }
        }
        .alert(
            "Couldn't update lesson",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.dismissActionError() } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.actionError ?? "") }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Loading lessons…")

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.retry() }
            }

        case .loaded:
            if let detail = viewModel.detail {
                if detail.lessons.isEmpty {
                    EmptyStateView(
                        title: "No Lessons Yet",
                        message: "Lessons for this course will appear here."
                    )
                } else {
                    lessonList(detail)
                }
            }
        }
    }

    private func lessonList(_ detail: CourseDetail) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(detail.course.instructor, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressSummaryView(
                        progress: detail.progress,
                        detailText: "\(detail.completedCount) of \(detail.lessons.count) lessons"
                    )
                }
                .padding(.vertical, 4)
            }

            Section("Lessons") {
                ForEach(detail.lessons) { lesson in
                    LessonRowView(
                        lesson: lesson,
                        isCompleting: viewModel.completingLessonId == lesson.id,
                        isActionDisabled: viewModel.completingLessonId != nil
                    ) {
                        Task { await viewModel.complete(lessonId: lesson.id) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
