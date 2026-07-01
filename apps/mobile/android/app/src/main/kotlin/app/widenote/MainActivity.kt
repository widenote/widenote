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
        super.onNewIntent(intent)
        setIntent(intent)
        BackupImportChannelHandler.handleIntent(this, intent)
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
