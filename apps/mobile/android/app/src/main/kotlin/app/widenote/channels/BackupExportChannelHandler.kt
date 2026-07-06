package app.widenote.channels

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

object BackupExportChannelHandler {
    private const val METHOD_CHANNEL = "app.widenote/backup_export"
    private const val BACKUP_MIME_TYPE = "application/x-widenote-backup"
    private const val REQUEST_CREATE_DOCUMENT = 0x574e10
    private const val REQUEST_OPEN_DOCUMENT = 0x574e11

    private var pendingSave: PendingFileOperation? = null
    private var pendingPick: MethodChannel.Result? = null

    fun register(activity: Activity, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareBackup" -> {
                        val path = call.argument<String>("path")
                        val displayName = call.argument<String>("displayName")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_path", "Backup path is required.", null)
                            return@setMethodCallHandler
                        }
                        shareBackup(activity, path, displayName)
                        result.success(null)
                    }
                    "saveBackup" -> {
                        val path = call.argument<String>("path")
                        val displayName = call.argument<String>("displayName")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_path", "Backup path is required.", null)
                            return@setMethodCallHandler
                        }
                        saveBackup(activity, path, displayName, result)
                    }
                    "pickBackup" -> pickBackup(activity, result)
                    else -> result.notImplemented()
                }
            }
    }

    fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        return when (requestCode) {
            REQUEST_CREATE_DOCUMENT -> {
                val pending = pendingSave
                pendingSave = null
                if (pending == null) {
                    true
                } else if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    try {
                        copyFileToUri(activity.contentResolver, pending.sourcePath, data.data!!)
                        pending.result.success(data.data!!.toString())
                    } catch (error: Exception) {
                        pending.result.error(
                            "save_failed",
                            error.message ?: "Backup save failed.",
                            null,
                        )
                    }
                    true
                } else {
                    pending.result.success(null)
                    true
                }
            }
            REQUEST_OPEN_DOCUMENT -> {
                val result = pendingPick
                pendingPick = null
                if (result == null) {
                    true
                } else if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val uri = data.data!!
                    val copiedPath = copyUriToCache(
                        activity,
                        activity.contentResolver,
                        uri,
                        displayName(activity.contentResolver, uri),
                    )
                    if (copiedPath == null) {
                        result.error(
                            "copy_failed",
                            "Selected backup file could not be read.",
                            null,
                        )
                    } else {
                        result.success(copiedPath)
                    }
                    true
                } else {
                    result.success(null)
                    true
                }
            }
            else -> false
        }
    }

    private fun shareBackup(activity: Activity, path: String, displayName: String?) {
        val source = File(path)
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.backup_file_provider",
            source,
        )
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = BACKUP_MIME_TYPE
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, displayName ?: source.name)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(sendIntent, displayName ?: source.name))
    }

    private fun saveBackup(
        activity: Activity,
        path: String,
        displayName: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingSave != null) {
            result.error("busy", "A backup save operation is already active.", null)
            return
        }
        val source = File(path)
        pendingSave = PendingFileOperation(path, result)
        val createIntent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = BACKUP_MIME_TYPE
            putExtra(Intent.EXTRA_TITLE, displayName ?: source.name)
        }
        @Suppress("DEPRECATION")
        try {
            activity.startActivityForResult(createIntent, REQUEST_CREATE_DOCUMENT)
        } catch (error: Exception) {
            pendingSave = null
            result.error("activity_not_found", error.message, null)
        }
    }

    private fun pickBackup(activity: Activity, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A backup picker operation is already active.", null)
            return
        }
        pendingPick = result
        val openIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(BACKUP_MIME_TYPE, "application/zip", "application/octet-stream"),
            )
        }
        @Suppress("DEPRECATION")
        try {
            activity.startActivityForResult(openIntent, REQUEST_OPEN_DOCUMENT)
        } catch (error: Exception) {
            pendingPick = null
            result.error("activity_not_found", error.message, null)
        }
    }

    private fun copyFileToUri(resolver: ContentResolver, sourcePath: String, uri: Uri) {
        FileInputStream(File(sourcePath)).use { input ->
            val outputStream = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("Unable to open backup destination.")
            outputStream.use { output ->
                val buffer = ByteArray(8 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read == -1) break
                    output.write(buffer, 0, read)
                }
            }
        }
    }

    private fun copyUriToCache(
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

    private data class PendingFileOperation(
        val sourcePath: String,
        val result: MethodChannel.Result,
    )
}
