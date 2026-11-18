package com.shortssplitter.shorts_splitter

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AudioRecorderBridge(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.shortssplitter.shorts_splitter/audio_recorder"
    }

    private var recorder: MediaRecorder? = null
    private var isRecording = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "Output path cannot be empty", null)
                    return
                }
                try {
                    val destFile = File(path)
                    destFile.parentFile?.mkdirs()

                    val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        MediaRecorder(context)
                    } else {
                        @Suppress("DEPRECATION")
                        MediaRecorder()
                    }

                    mr.setAudioSource(MediaRecorder.AudioSource.MIC)
                    mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    mr.setAudioEncodingBitRate(192000)
                    mr.setAudioSamplingRate(44100)
                    mr.setOutputFile(destFile.absolutePath)
                    mr.prepare()
                    mr.start()

                    recorder = mr
                    isRecording = true
                    result.success(true)
                } catch (e: Exception) {
                    recorder?.release()
                    recorder = null
                    isRecording = false
                    result.error("RECORDING_FAILED", "Failed to start recording: ${e.message}", null)
                }
            }

            "stopRecording" -> {
                try {
                    if (isRecording && recorder != null) {
                        recorder?.stop()
                        recorder?.release()
                        recorder = null
                        isRecording = false
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    recorder?.release()
                    recorder = null
                    isRecording = false
                    result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
                }
            }

            "isRecording" -> {
                result.success(isRecording)
            }

            else -> result.notImplemented()
        }
    }
}

