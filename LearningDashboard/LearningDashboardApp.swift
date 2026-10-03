//
//  LearningDashboardApp.swift
//  LearningDashboard
//

import SwiftUI

@main
struct LearningDashboardApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(dependencies.sessionManager)
                .environment(dependencies.networkMonitor)
        }
    }
}
