//
//  CourseListView.swift
//  LearningDashboard
//

import SwiftUI

struct CourseListView: View {

    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionManager.self) private var sessionManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var viewModel: CourseListViewModel
    @State private var path: [Course] = []

    init(viewModel: @autoclosure @escaping () -> CourseListViewModel) {
        _viewModel = State(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                OfflineBanner(dataSource: viewModel.dataSource)
                content
            }
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { optionsMenu }
            }
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(viewModel: dependencies.makeCourseDetailViewModel(for: course))
            }
            // Runs on every appearance, including when returning from the detail screen.
            .task { await viewModel.onAppear() }
            .onChange(of: networkMonitor.isOnline) { _, isOnline in
                guard isOnline else { return }
                Task { await viewModel.refresh() }
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if viewModel.courses.isEmpty {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Loading courses…")
            case .failed(let message):
                ErrorView(message: message) {
                    Task { await viewModel.load() }
                }
            case .loaded:
                EmptyStateView(
                    title: "No Courses Yet",
                    message: "Courses you enroll in will appear here."
                )
            }
        } else {
            courseList
        }
    }

    private var courseList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.courses) { course in
                    CourseCardView(course: course) {
                        path.append(course)
                    }
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Toolbar

    private var optionsMenu: some View {
        Menu {
            if AppConfiguration.useMockBackend {
                Section("Mock backend") {
                    Toggle(
                        "Simulate offline",
                        isOn: Binding(
                            get: { networkMonitor.simulatedOffline },
                            set: { networkMonitor.setSimulatedOffline($0) }
                        )
                    )
                    Toggle(
                        "Simulate API failure",
                        isOn: Binding(
                            get: { networkMonitor.simulatedApiFailure },
                            set: { networkMonitor.setSimulatedApiFailure($0) }
                        )
                    )
                    Toggle(
                        "Simulate empty list",
                        isOn: Binding(
                            get: { networkMonitor.simulatedEmptyData },
                            set: { networkMonitor.setSimulatedEmptyData($0) }
                        )
                    )
                    Button("Clear saved data & reload") {
                        Task { await viewModel.clearSavedDataAndReload() }
                    }
                }
            }

            Button("Log Out", role: .destructive) {
                sessionManager.logout()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel("Options")
        }
    }
}
