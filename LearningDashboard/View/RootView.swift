//
//  RootView.swift
//  LearningDashboard
//

import SwiftUI

/// Switches between Login and the Course Dashboard purely from session state,
/// so logging in / out (or an expired session later) never needs imperative navigation.
struct RootView: View {

    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                CourseListView(viewModel: dependencies.makeCourseListViewModel())
            } else {
                LoginView(viewModel: dependencies.makeLoginViewModel())
            }
        }
        .animation(.default, value: sessionManager.isAuthenticated)
    }
}
