package com.shortssplitter.shorts_splitter

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.provider.MediaStore
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Native Android storage helper supporting API 28 through API 35+.
 * Manages SAF tree URIs, MediaStore Video collection writes, pre-flight space probing,
 * and high-efficiency streaming of 1GB+ content URI video files.
 */
class StorageBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.shortssplitter.shorts_splitter/storage"
        private const val BUFFER_SIZE = 512 * 1024 // 512 KB high-throughput buffer for 1GB+ files
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSdkInt" -> {
                result.success(Build.VERSION.SDK_INT)
            }

            "takePersistableUriPermission" -> {
                val uriString = call.argument<String>("uri")
                if (uriString == null) {
                    result.error("INVALID_ARGS", "URI must not be null", null)
                    return
                }
                try {
                    val uri = Uri.parse(uriString)
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    context.contentResolver.takePersistableUriPermission(uri, flags)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SAF_PERMISSION_FAILED", "Failed to take persistable URI permission: ${e.message}", null)
                }
            }

            "isPersistedUriValid" -> {
                val uriString = call.argument<String>("uri")
                if (uriString == null) {
                    result.success(false)
                    return
                }
                try {
                    val uri = Uri.parse(uriString)
                    // Check if URI is in persistedUriPermissions
                    val persisted = context.contentResolver.persistedUriPermissions.any {
                        it.uri == uri && it.isWritePermission
                    }
                    if (!persisted) {
                        result.success(false)
                        return
                    }
                    val docFile = DocumentFile.fromTreeUri(context, uri)
                    result.success(docFile != null && docFile.exists() && docFile.canWrite())
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "createSafDirectory" -> {
                val treeUriString = call.argument<String>("treeUri")
                val dirName = call.argument<String>("dirName")
                if (treeUriString == null || dirName == null) {
                    result.error("INVALID_ARGS", "treeUri and dirName must not be null", null)
                    return
                }
                Thread {
                    try {
                        val treeUri = Uri.parse(treeUriString)
                        val parentDoc = if (treeUriString.contains("/document/")) {
                            DocumentFile.fromSingleUri(context, treeUri) ?: DocumentFile.fromTreeUri(context, treeUri)
                        } else {
                            DocumentFile.fromTreeUri(context, treeUri)
                        }
                        if (parentDoc == null || !parentDoc.canWrite()) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SAF_WRITE_DENIED", "Cannot write to selected SAF directory", null)
                            }
                            return@Thread
                        }
                        val existing = parentDoc.findFile(dirName)
                        if (existing != null && existing.isDirectory) {
                            Handler(Looper.getMainLooper()).post {
                                result.success(existing.uri.toString())
                            }
                            return@Thread
                        }
                        val newDir = parentDoc.createDirectory(dirName)
                        Handler(Looper.getMainLooper()).post {
                            if (newDir != null) {
                                result.success(newDir.uri.toString())
                            } else {
                                result.error("SAF_MKDIR_FAILED", "Could not create directory $dirName", null)
                            }
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("SAF_MKDIR_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            "renameSafDocument" -> {
                val docUriString = call.argument<String>("documentUri")
                val newName = call.argument<String>("newName")
                if (docUriString == null || newName == null) {
                    result.error("INVALID_ARGS", "documentUri and newName required", null)
                    return
                }
                Thread {
                    try {
                        val docUri = Uri.parse(docUriString)
                        val doc = DocumentFile.fromSingleUri(context, docUri)
                        val success = doc != null && doc.renameTo(newName)
                        Handler(Looper.getMainLooper()).post {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("SAF_RENAME_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            "deleteSafDocument" -> {
                val docUriString = call.argument<String>("documentUri")
                if (docUriString == null) {
                    result.error("INVALID_ARGS", "documentUri required", null)
                    return
                }
                Thread {
                    try {
                        val docUri = Uri.parse(docUriString)
                        val doc = DocumentFile.fromSingleUri(context, docUri)
                        var success = doc != null && doc.delete()
                        if (!success) {
                            try {
                                success = context.contentResolver.delete(docUri, null, null) > 0
                            } catch (_: Exception) {}
                        }
                        Handler(Looper.getMainLooper()).post {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("SAF_DELETE_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            "writeClipToSaf" -> {
                val tempFilePath = call.argument<String>("tempFilePath")
                val treeUriString = call.argument<String>("treeUri")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType") ?: "video/mp4"

                if (tempFilePath == null || treeUriString == null || fileName == null) {
                    result.error("INVALID_ARGS", "Missing required arguments for SAF write", null)
                    return
                }

                Thread {
                    try {
                        val sourceFile = File(tempFilePath)
                        if (!sourceFile.exists()) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SOURCE_NOT_FOUND", "Temporary source clip not found: $tempFilePath", null)
                            }
                            return@Thread
                        }

                        val treeUri = Uri.parse(treeUriString)
                        val treeDoc = if (treeUriString.contains("/document/")) {
                            DocumentFile.fromSingleUri(context, treeUri) ?: DocumentFile.fromTreeUri(context, treeUri)
                        } else {
                            DocumentFile.fromTreeUri(context, treeUri)
                        }
                        if (treeDoc == null || !treeDoc.canWrite()) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SAF_WRITE_DENIED", "Cannot write to selected SAF directory", null)
                            }
                            return@Thread
                        }

                        // Only scan tree if explicit overwrite requested to avoid directory scanning overhead
                        val overwrite = call.argument<Boolean>("overwrite") ?: false
                        if (overwrite) {
                            val existingFile = treeDoc.findFile(fileName)
                            if (existingFile != null && existingFile.exists()) {
                                existingFile.delete()
                            }
                        }

                        val newFileDoc = treeDoc.createFile(mimeType, fileName)
                        if (newFileDoc == null) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SAF_CREATE_FAILED", "Failed to create document in SAF folder: $fileName", null)
                            }
                            return@Thread
                        }

                        val outputStream = context.contentResolver.openOutputStream(newFileDoc.uri)
                        if (outputStream == null) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SAF_STREAM_FAILED", "Could not open output stream for SAF URI: ${newFileDoc.uri}", null)
                            }
                            return@Thread
                        }

                        FileInputStream(sourceFile).use { input ->
                            outputStream.use { output ->
                                copyStream(input, output)
                            }
                        }

                        Handler(Looper.getMainLooper()).post {
                            result.success(newFileDoc.uri.toString())
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("SAF_WRITE_ERROR", "Error writing clip via SAF: ${e.message}", null)
                        }
                    }
                }.start()
            }

            "writeClipToMediaStore" -> {
                // MediaStore with RELATIVE_PATH and IS_PENDING (API 29+ only)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("UNSUPPORTED_API", "MediaStore RELATIVE_PATH requires API 29+", null)
                    return
                }

                val tempFilePath = call.argument<String>("tempFilePath")
                val relativePath = call.argument<String>("relativePath") ?: "Movies/ShortsSplitter"
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType") ?: "video/mp4"

                if (tempFilePath == null || fileName == null) {
                    result.error("INVALID_ARGS", "Missing arguments for MediaStore write", null)
                    return
                }

                Thread {
                    try {
                        val sourceFile = File(tempFilePath)
                        if (!sourceFile.exists()) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SOURCE_NOT_FOUND", "Source temp clip not found", null)
                            }
                            return@Thread
                        }

                        val values = ContentValues().apply {
                            put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                            put(MediaStore.Video.Media.MIME_TYPE, mimeType)
                            put(MediaStore.Video.Media.RELATIVE_PATH, relativePath)
                            put(MediaStore.Video.Media.IS_PENDING, 1)
                            put(MediaStore.Video.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                        }

                        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                        val itemUri = context.contentResolver.insert(collection, values)
                        if (itemUri == null) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("MEDIASTORE_INSERT_FAILED", "Failed to insert record into MediaStore", null)
                            }
                            return@Thread
                        }

                        val outputStream = context.contentResolver.openOutputStream(itemUri)
                        if (outputStream == null) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("MEDIASTORE_STREAM_FAILED", "Could not open output stream for MediaStore item", null)
                            }
                            return@Thread
                        }

                        FileInputStream(sourceFile).use { input ->
                            outputStream.use { output ->
                                copyStream(input, output)
                            }
                        }

                        // Release pending state so gallery and players see the clip
                        values.clear()
                        values.put(MediaStore.Video.Media.IS_PENDING, 0)
                        context.contentResolver.update(itemUri, values, null, null)

                        Handler(Looper.getMainLooper()).post {
                            result.success(itemUri.toString())
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("MEDIASTORE_WRITE_ERROR", "Error saving clip to MediaStore: ${e.message}", null)
                        }
                    }
                }.start()
            }

            "getFreeDiskSpace" -> {
                val path = call.argument<String>("path") ?: context.filesDir.absolutePath
                try {
                    val file = File(path)
                    val targetDir = if (file.isDirectory) file else (file.parentFile ?: context.filesDir)
                    val stat = StatFs(targetDir.absolutePath)
                    val availableBytes = stat.availableBlocksLong * stat.blockSizeLong
                    result.success(availableBytes)
                } catch (e: Exception) {
                    // Fallback to internal storage stat
                    try {
                        val stat = StatFs(context.filesDir.absolutePath)
                        result.success(stat.availableBlocksLong * stat.blockSizeLong)
                    } catch (e2: Exception) {
                        result.success(1024L * 1024L * 1024L) // Safe default 1GB
                    }
                }
            }

            "copyContentUriToTempFile" -> {
                val contentUriString = call.argument<String>("contentUri")
                val tempDestPath = call.argument<String>("tempDestPath")

                if (contentUriString == null || tempDestPath == null) {
                    result.error("INVALID_ARGS", "Missing arguments for copying content URI", null)
                    return
                }

                try {
                    val uri = Uri.parse(contentUriString)
                    val inputStream = context.contentResolver.openInputStream(uri)
                    if (inputStream == null) {
                        result.error("STREAM_OPEN_FAILED", "Could not open input stream from content URI", null)
                        return
                    }

                    val destFile = File(tempDestPath)
                    destFile.parentFile?.mkdirs()

                    inputStream.use { input ->
                        FileOutputStream(destFile).use { output ->
                            copyStream(input, output)
                        }
                    }

                    result.success(destFile.absolutePath)
                } catch (e: Exception) {
                    result.error("COPY_CONTENT_ERROR", "Failed to stream content URI to temp file: ${e.message}", null)
                }
            }

            "scanMediaFile" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.success(false)
                    return
                }
                MediaScannerConnection.scanFile(
                    context,
                    arrayOf(filePath),
                    arrayOf("video/mp4")
                ) { _, uri ->
                    // Scan completed
                }
                result.success(true)
            }

            "isIgnoringBatteryOptimizations" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: true
                } else {
                    true
                }
                result.success(isIgnoring)
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun copyStream(input: InputStream, output: OutputStream) {
        val buffer = ByteArray(BUFFER_SIZE)
        var bytesRead: Int
        while (input.read(buffer).also { bytesRead = it } != -1) {
            output.write(buffer, 0, bytesRead)
        }
        output.flush()
    }
}

