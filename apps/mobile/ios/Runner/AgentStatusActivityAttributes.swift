import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct AgentStatusActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var status: String
    var title: String
    var body: String
    var runningCount: Int
    var queuedCount: Int
    var retryingCount: Int
    var attentionCount: Int
    var updatedAt: Date
    var staleAt: Date
  }

  var id: String
}
