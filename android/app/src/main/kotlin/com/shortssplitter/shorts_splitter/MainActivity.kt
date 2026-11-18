package com.shortssplitter.shorts_splitter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val ACTION_EXPORT_CANCELLED_BY_NOTIFICATION =
            "com.shortssplitter.shorts_splitter.EXPORT_CANCELLED"
        const val FOREGROUND_CHANNEL = "com.shortssplitter.shorts_splitter/foreground_service"
    }

    private var foregroundMethodChannel: MethodChannel? = null

    private val cancelReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_EXPORT_CANCELLED_BY_NOTIFICATION) {
                foregroundMethodChannel?.invokeMethod("onNotificationCancelAction", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Setup Storage Bridge Channel
        val storageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            StorageBridge.CHANNEL
        )
        storageChannel.setMethodCallHandler(StorageBridge(applicationContext))

        // 2. Setup Audio Recorder Bridge Channel
        val recorderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AudioRecorderBridge.CHANNEL
        )
        recorderChannel.setMethodCallHandler(AudioRecorderBridge(applicationContext))

        // 3. Setup Foreground Service Channel
        foregroundMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_CHANNEL
        )
        foregroundMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startOrUpdateService" -> {
                    val title = call.argument<String>("title") ?: "Exporting Video Clips"
                    val message = call.argument<String>("message") ?: "Processing..."
                    val progress = call.argument<Int>("progress") ?: 0
                    ExportForegroundService.startOrUpdate(applicationContext, title, message, progress)
                    result.success(true)
                }

                "stopService" -> {
                    ExportForegroundService.stop(applicationContext)
                    result.success(true)
                }

                "showCompletedNotification" -> {
                    val title = call.argument<String>("title") ?: "Export Complete"
                    val message = call.argument<String>("message") ?: "All clips exported successfully."
                    ExportForegroundService.showCompleted(applicationContext, title, message)
                    result.success(true)
                }

                "isServiceRunning" -> {
                    result.success(ExportForegroundService.isRunning)
                }

                else -> result.notImplemented()
            }
        }

        // Register broadcast receiver for notification cancel events
        val filter = IntentFilter(ACTION_EXPORT_CANCELLED_BY_NOTIFICATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(cancelReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(cancelReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(cancelReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
