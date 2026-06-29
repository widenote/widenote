package app.widenote.channels

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

object BackupImportChannelHandler {
    private const val METHOD_CHANNEL = "app.widenote/backup_import"
    private const val EVENT_CHANNEL = "app.widenote/backup_import_events"
    private const val BACKUP_MIME_TYPE = "application/x-widenote-backup"

    @Volatile
    private var pendingBackupPath: String? = null
    private var eventSink: EventChannel.EventSink? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialBackupPath" -> result.success(pendingBackupPath)
                    "clearInitialBackupPath" -> {
                        pendingBackupPath = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingBackupPath?.let { eventSink?.success(it) }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    fun handleIntent(activity: Activity, intent: Intent?) {
        val sourceIntent = intent ?: return
        val uri = backupUri(sourceIntent) ?: return
        val resolver = activity.contentResolver
        val mimeType = sourceIntent.type ?: resolver.getType(uri)
        val displayName = displayName(resolver, uri)
        if (!looksLikeWideNoteBackup(uri, displayName, mimeType)) return

        Thread {
            val copiedPath = copyToCache(activity, resolver, uri, displayName)
            if (copiedPath != null) {
                pendingBackupPath = copiedPath
                activity.runOnUiThread { eventSink?.success(copiedPath) }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun backupUri(intent: Intent): Uri? {
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.data ?: intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
    }

    private fun looksLikeWideNoteBackup(
        uri: Uri,
        displayName: String?,
        mimeType: String?,
    ): Boolean {
        return mimeType == BACKUP_MIME_TYPE ||
            displayName?.endsWith(".widenote", ignoreCase = true) == true ||
            uri.lastPathSegment?.endsWith(".widenote", ignoreCase = true) == true
    }

    private fun copyToCache(
        activity: Activity,
        resolver: ContentResolver,
        uri: Uri,
        displayName: String?,
    ): String? {
        return try {
            val importDir = File(activity.cacheDir, "backup_imports")
            if (!importDir.exists()) importDir.mkdirs()
            val destination = File(importDir, sanitizeBackupFileName(displayName ?: uri.lastPathSegment))
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(8 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        output.write(buffer, 0, read)
                    }
                }
            } ?: return null
            destination.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun displayName(resolver: ContentResolver, uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } catch (_: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun sanitizeBackupFileName(rawName: String?): String {
        val fallback = "widenote_backup_${System.currentTimeMillis()}.widenote"
        val baseName = rawName
            ?.substringAfterLast('/')
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?.takeIf { it.isNotBlank() }
            ?: fallback
        return if (baseName.endsWith(".widenote", ignoreCase = true)) {
            baseName
        } else {
            "$baseName.widenote"
        }
    }
}
