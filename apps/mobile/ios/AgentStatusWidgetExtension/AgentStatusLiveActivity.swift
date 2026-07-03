import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AgentStatusWidgetBundle: WidgetBundle {
  var body: some Widget {
    AgentStatusLiveActivity()
  }
}

struct AgentStatusLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AgentStatusActivityAttributes.self) { context in
      AgentStatusLockScreenView(state: context.state)
        .activityBackgroundTint(.black.opacity(0.86))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          AgentStatusCount(
            systemImage: "bolt.circle",
            count: context.state.runningCount
          )
        }
        DynamicIslandExpandedRegion(.trailing) {
          AgentStatusCount(
            systemImage: "clock",
            count: context.state.queuedCount
          )
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.body)
            .font(.caption)
            .lineLimit(2)
        }
      } compactLeading: {
        Image(systemName: iconName(for: context.state.status))
      } compactTrailing: {
        Text("\(context.state.runningCount)/\(context.state.queuedCount)")
          .monospacedDigit()
      } minimal: {
        Image(systemName: iconName(for: context.state.status))
      }
    }
  }
}

private struct AgentStatusLockScreenView: View {
  let state: AgentStatusActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: iconName(for: state.status))
        Text(state.title)
          .font(.headline)
          .lineLimit(1)
        Spacer(minLength: 8)
        Text(state.updatedAt, style: .time)
          .font(.caption)
          .monospacedDigit()
      }
      Text(state.body)
        .font(.subheadline)
        .lineLimit(2)
      HStack(spacing: 12) {
        AgentStatusCount(systemImage: "bolt.circle", count: state.runningCount)
        AgentStatusCount(systemImage: "clock", count: state.queuedCount)
        AgentStatusCount(
          systemImage: "arrow.clockwise",
          count: state.retryingCount
        )
        AgentStatusCount(
          systemImage: "exclamationmark.circle",
          count: state.attentionCount
        )
      }
    }
    .foregroundStyle(.white)
    .padding()
  }
}

private struct AgentStatusCount: View {
  let systemImage: String
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: systemImage)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text("\(count)")
        .font(.caption)
        .fontWeight(.semibold)
        .monospacedDigit()
    }
  }
}

private func iconName(for status: String) -> String {
  switch status {
  case "attention":
    return "exclamationmark.circle"
  case "completed":
    return "checkmark.circle"
  default:
    return "bolt.circle"
  }
}
