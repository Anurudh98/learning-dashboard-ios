//
//  StatusBanner.swift
//  LearningDashboard
//

import SwiftUI

struct StatusBanner: View {

    let message: String
    var systemImage: String = "info.circle.fill"
    var tint: Color = .orange

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12))
            .accessibilityElement(children: .combine)
    }
}

/// Tells the user they are looking at saved data. Shown when the device is offline, or when the
/// server could not be reached and the saved copy was used instead.
struct OfflineBanner: View {

    let dataSource: DataSource
    @Environment(NetworkMonitor.self) private var networkMonitor

    var body: some View {
        if !networkMonitor.isOnline {
            StatusBanner(
                message: "You're offline. Showing saved data.",
                systemImage: "wifi.slash"
            )
        } else if dataSource == .cache {
            StatusBanner(
                message: "Couldn't reach the server. Showing saved data.",
                systemImage: "exclamationmark.icloud"
            )
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusBanner(message: "You're offline. Showing saved data.", systemImage: "wifi.slash")
        StatusBanner(message: "Saved on this device.", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
    }
}
