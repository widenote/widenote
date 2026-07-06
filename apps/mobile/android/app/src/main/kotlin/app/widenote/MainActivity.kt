package app.widenote

import android.content.Intent
import android.os.Bundle
import app.widenote.channels.BackupExportChannelHandler
import app.widenote.channels.BackupImportChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BackupImportChannelHandler.handleIntent(this, intent)
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
        BackupImportChannelHandler.handleIntent(this, intent)
    }

    override fun getInitialRoute(): String? {
        if (BackupImportChannelHandler.isBackupImportIntent(this, intent)) {
            return "/"
        }
        return super.getInitialRoute()
    }

    override fun shouldHandleDeeplinking(): Boolean {
        if (BackupImportChannelHandler.isBackupImportIntent(this, intent)) {
            return false
        }
        return super.shouldHandleDeeplinking()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BackupImportChannelHandler.register(flutterEngine)
        BackupExportChannelHandler.register(this, flutterEngine)
    }

    @Deprecated("Deprecated in Android framework; required by document intents.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (BackupExportChannelHandler.onActivityResult(this, requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
