package com.example.sheepify

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "sheepify/inbox"
        private var channel: MethodChannel? = null

        /** Tells a running app that new bank alerts / a shared image arrived. */
        fun notifyInboxChanged() {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("inboxChanged", null)
            }
        }
    }

    private var sharedImagePath: String? = null
    private var openInboxRequested = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isListenerEnabled" -> result.success(isListenerEnabled())
                "openListenerSettings" -> {
                    openListenerSettings()
                    result.success(null)
                }
                "drainBankAlerts" -> result.success(BankAlertStore.drain(this))
                "takeSharedImage" -> {
                    result.success(sharedImagePath)
                    sharedImagePath = null
                }
                "takeOpenInboxRequest" -> {
                    result.success(openInboxRequested)
                    openInboxRequested = false
                }
                else -> result.notImplemented()
            }
        }
        channel = methodChannel
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        notifyInboxChanged()
    }

    override fun onDestroy() {
        if (isFinishing) channel = null
        super.onDestroy()
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra(BankAlertStore.EXTRA_OPEN_INBOX, false)) {
            openInboxRequested = true
            intent.removeExtra(BankAlertStore.EXTRA_OPEN_INBOX)
        }
        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("image/") == true) {
            val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            if (uri != null) sharedImagePath = copyToCache(uri)
            // Consume it so a re-delivery doesn't import the same image twice.
            intent.action = Intent.ACTION_MAIN
        }
    }

    private fun copyToCache(uri: Uri): String? = try {
        val dir = File(cacheDir, "shared")
        dir.mkdirs()
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "receipt_" + System.currentTimeMillis() + ".jpg")
        contentResolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        }
        if (file.length() > 0) file.absolutePath else null
    } catch (_: Exception) {
        null
    }

    private fun isListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        val me = ComponentName(this, BankNotificationListener::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == me }
    }

    private fun openListenerSettings() {
        val component = ComponentName(this, BankNotificationListener::class.java)
        val detail = if (Build.VERSION.SDK_INT >= 30) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
        } else {
            null
        }
        try {
            startActivity(detail ?: Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }
}
