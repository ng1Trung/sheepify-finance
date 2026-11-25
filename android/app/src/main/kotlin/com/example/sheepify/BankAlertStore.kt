package com.example.sheepify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Queue of bank balance-change notifications seen while Sheepify may not be
 * running. Only notifications that look like a bank alert are kept; nothing
 * leaves the device. Flutter drains the queue when the app is opened.
 */
object BankAlertStore {
    private const val PREFS = "sheepify_bank_alerts"
    private const val KEY_QUEUE = "queue"
    private const val KEY_SEEN = "seen"
    private const val MAX_QUEUE = 50
    private const val MAX_SEEN = 100

    const val CHANNEL_ID = "sheepify_bank_alerts"
    const val NOTIFICATION_ID = 4521
    const val EXTRA_OPEN_INBOX = "sheepify_open_bank_inbox"

    /** Bank / e-wallet apps (same list the app can open for transfers). */
    private val knownBankPackages = setOf(
        "com.VCB", "vn.com.techcombank.bb.app", "com.mbmobile",
        "com.tpb.mb.gprsandroid", "com.mservice.momopay", "com.vng.zalopay",
        "com.vnpay.bidv", "com.vietinbank.ipay", "mobile.acb.com.vn",
        "com.vnpay.vpbankonline", "io.lifestyle.plus", "vn.timo.mobile",
        "xyz.be.cake", "vn.com.ocb.awe", "com.vnpay.agribank",
        "com.vib.myvib2", "com.vng.vib", "com.vnpay.sacombank",
        "com.vnpay.shb", "com.vnpay.hdbank", "com.vnpay.lpb",
        "com.bplus.vtpay",
    )

    // "-50,000 VND", "+1.200.000đ", "- 35,000 VND"
    private val signedAmount = Regex(
        "[+\\-]\\s?\\d{1,3}(?:[.,]\\d{3})+\\s?(?:VND|VNĐ|đ|₫)",
        RegexOption.IGNORE_CASE,
    )
    private val balanceWord = Regex(
        "(số dư|so du|\\bSD\\b|\\bSDC\\b|balance|biến động|bien dong)",
        RegexOption.IGNORE_CASE,
    )

    fun looksLikeBankAlert(pkg: String, text: String): Boolean {
        if (!signedAmount.containsMatchIn(text)) return false
        // Unknown senders (e.g. SMS banking) must also mention a balance, so a
        // chat message containing "-50,000đ" isn't taken for a payment.
        return pkg in knownBankPackages || balanceWord.containsMatchIn(text)
    }

    /** Returns true when the alert is new (not a re-post of one already seen). */
    @Synchronized
    fun add(context: Context, pkg: String, appName: String, text: String, time: Long): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = pkg + "|" + text.hashCode()
        val seen = JSONArray(prefs.getString(KEY_SEEN, "[]"))
        for (i in 0 until seen.length()) if (seen.optString(i) == key) return false
        seen.put(key)
        while (seen.length() > MAX_SEEN) seen.remove(0)

        val queue = JSONArray(prefs.getString(KEY_QUEUE, "[]"))
        queue.put(
            JSONObject()
                .put("id", key)
                .put("package", pkg)
                .put("app", appName)
                .put("text", text)
                .put("time", time)
        )
        while (queue.length() > MAX_QUEUE) queue.remove(0)

        prefs.edit()
            .putString(KEY_SEEN, seen.toString())
            .putString(KEY_QUEUE, queue.toString())
            .apply()
        return true
    }

    @Synchronized
    fun drain(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = prefs.getString(KEY_QUEUE, "[]") ?: "[]"
        prefs.edit().putString(KEY_QUEUE, "[]").apply()
        cancelNotification(context)
        return queue
    }

    private fun pendingCount(context: Context): Int =
        JSONArray(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_QUEUE, "[]")
        ).length()

    /** One updating notification; tapping it opens the inbox in the app. */
    fun notifyUser(context: Context, appName: String, text: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Giao dịch từ ngân hàng",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            channel.description = "Gợi ý ghi sổ khi ngân hàng báo biến động số dư"
            manager.createNotificationChannel(channel)
        }
        val open = Intent(context, MainActivity::class.java)
        open.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        open.putExtra(EXTRA_OPEN_INBOX, true)
        val pending = PendingIntent.getActivity(
            context, NOTIFICATION_ID, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val count = pendingCount(context)
        val title = if (count > 1) "$count giao dịch chưa ghi sổ" else "Ghi sổ giao dịch này?"
        val body = appName + ": " + text.replace("\n", " ").take(120)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
        }
    }

    fun cancelNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}
