//
//  ProgressSummaryView.swift
//  LearningDashboard
//

import SwiftUI

struct ProgressSummaryView: View {

    let progress: Int
    var detailText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(progress)% complete")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(progress), total: 100)
                .animation(.snappy, value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(progress) percent complete")
    }
}

#Preview {
    ProgressSummaryView(progress: 65, detailText: "13 of 20 lessons")
        .padding()
}
