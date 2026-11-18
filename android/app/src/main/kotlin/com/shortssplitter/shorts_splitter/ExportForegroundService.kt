package com.shortssplitter.shorts_splitter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground Service ensuring long-running FFmpeg video export jobs survive app backgrounding
 * and Doze mode across Android 9 (API 28) through Android 15+ (API 35+).
 */
class ExportForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "shorts_splitter_export_channel"
        const val NOTIFICATION_ID = 9001
        const val COMPLETED_NOTIFICATION_ID = 9002

        const val ACTION_START_OR_UPDATE = "com.shortssplitter.ACTION_START_OR_UPDATE"
        const val ACTION_STOP = "com.shortssplitter.ACTION_STOP"
        const val ACTION_CANCEL_EXPORT = "com.shortssplitter.ACTION_CANCEL_EXPORT"
        const val ACTION_SHOW_COMPLETED = "com.shortssplitter.ACTION_SHOW_COMPLETED"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_MESSAGE = "extra_message"
        const val EXTRA_PROGRESS = "extra_progress" // 0 to 100

        var isRunning = false
            private set

        fun startOrUpdate(context: Context, title: String, message: String, progress: Int) {
            val intent = Intent(context, ExportForegroundService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_MESSAGE, message)
                putExtra(EXTRA_PROGRESS, progress)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun showCompleted(context: Context, title: String, message: String) {
            val intent = Intent(context, ExportForegroundService::class.java).apply {
                action = ACTION_SHOW_COMPLETED
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_MESSAGE, message)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ExportForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == ACTION_STOP) {
            stopForegroundService()
            return START_NOT_STICKY
        }

        if (action == ACTION_CANCEL_EXPORT) {
            val cancelIntent = Intent(MainActivity.ACTION_EXPORT_CANCELLED_BY_NOTIFICATION)
            sendBroadcast(cancelIntent)
            stopForegroundService()
            return START_NOT_STICKY
        }

        if (action == ACTION_SHOW_COMPLETED) {
            val title = intent.getStringExtra(EXTRA_TITLE) ?: "Export Complete"
            val message = intent.getStringExtra(EXTRA_MESSAGE) ?: "All clips exported successfully."
            showCompletionNotification(title, message)
            stopForegroundService()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Exporting YouTube Shorts"
        val message = intent?.getStringExtra(EXTRA_MESSAGE) ?: "Processing video clips..."
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0

        val notification = buildNotification(title, message, progress)

        if (!isRunning) {
            acquireWakeLock()
            startForegroundWithType(notification)
            isRunning = true
        } else {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        }

        return START_NOT_STICKY
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = powerManager?.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "ShortsSplitter:ExportWakeLock"
                )?.apply {
                    setReferenceCounted(false)
                    acquire(60 * 60 * 1000L) // 1-hour max timeout safety
                }
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
    }

    private fun startForegroundWithType(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 35) { // Android 15+ (API 35)
            try {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
                )
                return
            } catch (e: Exception) {
                // Fallback to dataSync if mediaProcessing encounters policy restrictions
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14 (API 34)
            try {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
                return
            } catch (e: Exception) {
                // Fallback to legacy
            }
        }

        // Android 9 to 13 (API 28-33)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(title: String, message: String, progress: Int): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/processing")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val cancelIntent = Intent(this, ExportForegroundService::class.java).apply {
            action = ACTION_CANCEL_EXPORT
        }
        val cancelPendingIntent = PendingIntent.getService(
            this,
            1,
            cancelIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)
            .setProgress(100, progress.coerceIn(0, 100), progress <= 0)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun showCompletionNotification(title: String, message: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/results")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            2,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(COMPLETED_NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Video Exporting Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress during video splitting and encoding"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun stopForegroundService() {
        releaseWakeLock()
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15+ (API 35+) and Android 16 (API 36) foreground service timeout handling
        val cancelIntent = Intent(MainActivity.ACTION_EXPORT_CANCELLED_BY_NOTIFICATION)
        sendBroadcast(cancelIntent)
        stopForegroundService()
    }

    override fun onDestroy() {
        releaseWakeLock()
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
