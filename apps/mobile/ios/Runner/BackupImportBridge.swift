import Flutter
import Foundation
import UIKit

final class BackupImportBridge: NSObject, FlutterStreamHandler, UIDocumentPickerDelegate {
  private static let shared = BackupImportBridge()
  private static let methodChannelName = "app.widenote/backup_import"
  private static let eventChannelName = "app.widenote/backup_import_events"
  private static let exportMethodChannelName = "app.widenote/backup_export"

  private var pendingBackupPath: String?
  private var eventSink: FlutterEventSink?
  private var pendingDocumentResult: FlutterResult?
  private var pendingDocumentMode: DocumentMode?

  static func register(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialBackupPath":
        result(shared.pendingBackupPath)
      case "clearInitialBackupPath":
        shared.pendingBackupPath = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let exportMethodChannel = FlutterMethodChannel(
      name: exportMethodChannelName,
      binaryMessenger: messenger
    )
    exportMethodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "shareBackup":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(FlutterError(code: "invalid_path", message: "Backup path is required.", details: nil))
          return
        }
        shared.shareBackup(path: path, result: result)
      case "saveBackup":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String
        else {
          result(FlutterError(code: "invalid_path", message: "Backup path is required.", details: nil))
          return
        }
        shared.saveBackup(path: path, result: result)
      case "pickBackup":
        shared.pickBackup(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(shared)
  }

  static func handle(url: URL) {
    guard looksLikeWideNoteBackup(url: url) else {
      return
    }

    DispatchQueue.global(qos: .utility).async {
      guard let path = shared.copyToCache(url: url) else {
        return
      }
      DispatchQueue.main.async {
        shared.pendingBackupPath = path
        shared.eventSink?(path)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    if let path = pendingBackupPath {
      events(path)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private static func looksLikeWideNoteBackup(url: URL) -> Bool {
    return url.pathExtension.lowercased() == "widenote"
  }

  private func copyToCache(url: URL) -> String? {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let fileManager = FileManager.default
      let importDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("backup_imports", isDirectory: true)
      try fileManager.createDirectory(
        at: importDirectory,
        withIntermediateDirectories: true
      )
      let destination = importDirectory
        .appendingPathComponent(Self.sanitizeBackupFileName(url.lastPathComponent))
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try streamCopy(from: url, to: destination)
      return destination.path
    } catch {
      return nil
    }
  }

  private func shareBackup(path: String, result: @escaping FlutterResult) {
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_presenter", message: "No view controller is available.", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activity, animated: true)
    result(nil)
  }

  private func saveBackup(path: String, result: @escaping FlutterResult) {
    guard pendingDocumentResult == nil else {
      result(FlutterError(code: "busy", message: "A document picker is already active.", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_presenter", message: "No view controller is available.", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    pendingDocumentResult = result
    pendingDocumentMode = .export
    let picker = UIDocumentPickerViewController(url: url, in: .exportToService)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func pickBackup(result: @escaping FlutterResult) {
    guard pendingDocumentResult == nil else {
      result(FlutterError(code: "busy", message: "A document picker is already active.", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_presenter", message: "No view controller is available.", details: nil))
      return
    }
    pendingDocumentResult = result
    pendingDocumentMode = .importBackup
    let picker = UIDocumentPickerViewController(
      documentTypes: ["app.widenote.backup", "public.zip-archive", "public.data"],
      in: .import
    )
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingDocumentResult else {
      return
    }
    let mode = pendingDocumentMode
    pendingDocumentResult = nil
    pendingDocumentMode = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    switch mode {
    case .export:
      result(url.absoluteString)
    case .importBackup:
      if let path = copyToCache(url: url) {
        result(path)
      } else {
        result(FlutterError(
          code: "copy_failed",
          message: "Selected backup file could not be read.",
          details: nil
        ))
      }
    case .none:
      result(nil)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingDocumentResult?(nil)
    pendingDocumentResult = nil
    pendingDocumentMode = nil
  }

  private func streamCopy(from source: URL, to destination: URL) throws {
    guard let input = InputStream(url: source) else {
      throw CocoaError(.fileReadUnknown)
    }
    guard let output = OutputStream(url: destination, append: false) else {
      throw CocoaError(.fileWriteUnknown)
    }
    input.open()
    output.open()
    defer {
      input.close()
      output.close()
    }

    let bufferSize = 8 * 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer {
      buffer.deallocate()
    }

    while input.hasBytesAvailable {
      let read = input.read(buffer, maxLength: bufferSize)
      if read < 0 {
        throw input.streamError ?? CocoaError(.fileReadUnknown)
      }
      if read == 0 {
        break
      }
      var written = 0
      while written < read {
        let count = output.write(buffer.advanced(by: written), maxLength: read - written)
        if count <= 0 {
          throw output.streamError ?? CocoaError(.fileWriteUnknown)
        }
        written += count
      }
    }
  }

  private static func sanitizeBackupFileName(_ rawName: String) -> String {
    let fallback = "widenote_backup_\(Int(Date().timeIntervalSince1970)).widenote"
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    let underscore = UnicodeScalar("_")
    let sanitizedScalars = rawName.unicodeScalars.map { scalar in
      allowed.contains(scalar) ? scalar : underscore
    }
    let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
      .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    let baseName = sanitized.isEmpty ? fallback : sanitized
    return baseName.lowercased().hasSuffix(".widenote")
      ? baseName
      : "\(baseName).widenote"
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let window = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    return topViewController(from: window?.rootViewController)
  }

  private static func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }

  private enum DocumentMode {
    case export
    case importBackup
  }
}
