import Flutter
import Foundation

final class BackupImportBridge: NSObject, FlutterStreamHandler {
  private static let shared = BackupImportBridge()
  private static let methodChannelName = "app.widenote/backup_import"
  private static let eventChannelName = "app.widenote/backup_import_events"

  private var pendingBackupPath: String?
  private var eventSink: FlutterEventSink?

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
}
