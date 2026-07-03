import Flutter
import Foundation
import UIKit
import UserNotifications

#if canImport(ActivityKit)
import ActivityKit
#endif

final class AgentStatusBridge {
  private static let channelName = "app.widenote/agent_status"
  private static let notificationIdentifier = "app.widenote.agent_status.current"
  private static let notificationThreadIdentifier = "app.widenote.agent_status"
  private static let liveActivityId = "app.widenote.agent_status.aggregate"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "syncStatus" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let payload = call.arguments as? [String: Any],
            let status = AgentStatusPayload(payload: payload) else {
        result(
          FlutterError(
            code: "bad_payload",
            message: "Agent status payload is malformed.",
            details: nil
          )
        )
        return
      }
      sync(status) { syncResult in
        result(syncResult.asDictionary)
      }
    }
  }

  private static func sync(
    _ payload: AgentStatusPayload,
    completion: @escaping (AgentStatusSyncResult) -> Void
  ) {
    if payload.status == "idle" {
      clearNotification()
      syncLiveActivity(payload) { liveActivityStatus in
        completion(
          AgentStatusSyncResult(
            notificationStatus: "cleared",
            liveActivityStatus: liveActivityStatus
          )
        )
      }
      return
    }

    syncNotification(payload) { notificationStatus in
      syncLiveActivity(payload) { liveActivityStatus in
        completion(
          AgentStatusSyncResult(
            notificationStatus: notificationStatus,
            liveActivityStatus: liveActivityStatus
          )
        )
      }
    }
  }

  private static func syncNotification(
    _ payload: AgentStatusPayload,
    completion: @escaping (String) -> Void
  ) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        scheduleNotification(payload, completion: completion)
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .badge]) { granted, _ in
          guard granted else {
            completion("denied")
            return
          }
          scheduleNotification(payload, completion: completion)
        }
      case .denied:
        clearNotification()
        completion("denied")
      @unknown default:
        completion("unknown")
      }
    }
  }

  private static func scheduleNotification(
    _ payload: AgentStatusPayload,
    completion: @escaping (String) -> Void
  ) {
    let content = UNMutableNotificationContent()
    content.title = payload.title
    content.body = payload.body
    content.threadIdentifier = notificationThreadIdentifier
    content.userInfo = [
      "target": "agent_status",
      "status": payload.status,
    ]
    if #available(iOS 15.0, *), payload.status == "attention" {
      content.interruptionLevel = .active
    }
    let request = UNNotificationRequest(
      identifier: notificationIdentifier,
      content: content,
      trigger: nil
    )
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    center.add(request) { error in
      completion(error == nil ? "scheduled" : "failed")
    }
  }

  private static func clearNotification() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
  }

  private static func syncLiveActivity(
    _ payload: AgentStatusPayload,
    completion: @escaping (String) -> Void
  ) {
#if canImport(ActivityKit)
    guard #available(iOS 16.2, *) else {
      completion("unsupported")
      return
    }
    Task {
      let result = await syncLiveActivityOnMain(payload)
      DispatchQueue.main.async {
        completion(result)
      }
    }
#else
    completion("unsupported")
#endif
  }

#if canImport(ActivityKit)
  @available(iOS 16.2, *)
  @MainActor
  private static func syncLiveActivityOnMain(_ payload: AgentStatusPayload) async -> String {
    let content = activityContent(for: payload)
    let existing = Activity<AgentStatusActivityAttributes>.activities.first {
      $0.attributes.id == liveActivityId
    }

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      if let existing {
        await existing.end(content, dismissalPolicy: .immediate)
        return "disabled_ended"
      }
      return "disabled"
    }

    if payload.status == "idle" {
      if let existing {
        await existing.end(content, dismissalPolicy: .immediate)
        return "ended"
      }
      return "idle"
    }

    if payload.hasActiveWork {
      if let existing {
        await existing.update(content)
        return "updated"
      }
      do {
        _ = try Activity.request(
          attributes: AgentStatusActivityAttributes(id: liveActivityId),
          content: content,
          pushType: nil
        )
        return "started"
      } catch {
        return "failed"
      }
    }

    if let existing {
      await existing.end(
        content,
        dismissalPolicy: .after(Date().addingTimeInterval(10 * 60))
      )
      return "ending"
    }

    do {
      let activity = try Activity.request(
        attributes: AgentStatusActivityAttributes(id: liveActivityId),
        content: content,
        pushType: nil
      )
      await activity.end(
        content,
        dismissalPolicy: .after(Date().addingTimeInterval(10 * 60))
      )
      return "terminal"
    } catch {
      return "failed"
    }
  }

  @available(iOS 16.2, *)
  private static func activityContent(
    for payload: AgentStatusPayload
  ) -> ActivityContent<AgentStatusActivityAttributes.ContentState> {
    let state = AgentStatusActivityAttributes.ContentState(
      status: payload.status,
      title: payload.title,
      body: payload.body,
      runningCount: payload.runningCount,
      queuedCount: payload.queuedCount,
      retryingCount: payload.retryingCount + payload.recoveringCount,
      attentionCount: payload.attentionCount,
      updatedAt: payload.updatedAt,
      staleAt: payload.staleAt
    )
    return ActivityContent(state: state, staleDate: payload.staleAt)
  }
#endif
}

private struct AgentStatusPayload {
  let status: String
  let title: String
  let body: String
  let runningCount: Int
  let queuedCount: Int
  let retryingCount: Int
  let recoveringCount: Int
  let failedCount: Int
  let blockedCount: Int
  let deniedCount: Int
  let canceledCount: Int
  let succeededCount: Int
  let updatedAt: Date
  let staleAt: Date
  let hasActiveWork: Bool

  init?(payload: [String: Any]) {
    guard let status = payload["status"] as? String,
          let title = payload["title"] as? String,
          let body = payload["body"] as? String else {
      return nil
    }
    self.status = status
    self.title = title
    self.body = body
    self.runningCount = AgentStatusPayload.int(payload["running_count"])
    self.queuedCount = AgentStatusPayload.int(payload["queued_count"])
    self.retryingCount = AgentStatusPayload.int(payload["retrying_count"])
    self.recoveringCount = AgentStatusPayload.int(payload["recovering_count"])
    self.failedCount = AgentStatusPayload.int(payload["failed_count"])
    self.blockedCount = AgentStatusPayload.int(payload["blocked_count"])
    self.deniedCount = AgentStatusPayload.int(payload["denied_count"])
    self.canceledCount = AgentStatusPayload.int(payload["canceled_count"])
    self.succeededCount = AgentStatusPayload.int(payload["succeeded_count"])
    self.updatedAt = AgentStatusPayload.date(payload["updated_at"]) ?? Date()
    self.staleAt = AgentStatusPayload.date(payload["stale_at"]) ??
      Date().addingTimeInterval(15 * 60)
    self.hasActiveWork = payload["has_active_work"] as? Bool ?? false
  }

  var attentionCount: Int {
    failedCount + blockedCount + deniedCount + canceledCount
  }

  private static func int(_ value: Any?) -> Int {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return 0
  }

  private static func date(_ value: Any?) -> Date? {
    guard let string = value as? String else {
      return nil
    }
    return ISO8601DateFormatter().date(from: string)
  }
}

private struct AgentStatusSyncResult {
  let notificationStatus: String
  let liveActivityStatus: String

  var asDictionary: [String: String] {
    [
      "notification_status": notificationStatus,
      "live_activity_status": liveActivityStatus,
    ]
  }
}
