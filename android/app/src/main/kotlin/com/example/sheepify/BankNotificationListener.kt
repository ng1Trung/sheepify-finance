package com.example.sheepify

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Sees bank "balance changed" notifications so a payment made directly in a
 * bank app can still be logged with one tap. Everything else is ignored and
 * nothing is stored for it.
 */
class BankNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            if (sbn.packageName == packageName) return
            val notification = sbn.notification ?: return
            if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

            val extras = notification.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
            val body = listOf(title, text).filter { it.isNotBlank() }.joinToString("\n")
            if (body.isBlank() || !BankAlertStore.looksLikeBankAlert(sbn.packageName, body)) return

            val appName = try {
                val info = packageManager.getApplicationInfo(sbn.packageName, 0)
                packageManager.getApplicationLabel(info).toString()
            } catch (_: Exception) {
                sbn.packageName
            }
            if (BankAlertStore.add(this, sbn.packageName, appName, body, sbn.postTime)) {
                BankAlertStore.notifyUser(this, appName, body)
                MainActivity.notifyInboxChanged()
            }
        } catch (_: Exception) {
            // Never let a malformed notification crash the listener.
        }
    }
}
