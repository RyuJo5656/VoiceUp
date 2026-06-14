package com.ryujo.voiceup

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the call-mode feature.
 *
 * Dart calls `setCallMode` over the `voiceup/audio_route` channel with one of
 * "off" / "private" / "public". We toggle the loudspeaker so that, during a
 * phone call, the amplified TTS is heard by the other party:
 *  - private: speakerphone ON (at home / in a car).
 *  - public:  speakerphone OFF — the call stays on the earpiece/Bluetooth so
 *             only the phone's own TTS plays out loud, not the conversation.
 *  - off:     leave routing untouched.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "voiceup/audio_route"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallMode" -> {
                        val mode = call.argument<String>("mode") ?: "off"
                        applyCallMode(mode)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyCallMode(mode: String) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (mode) {
            "private" -> {
                audio.mode = AudioManager.MODE_IN_COMMUNICATION
                @Suppress("DEPRECATION")
                audio.isSpeakerphoneOn = true
            }
            "public" -> {
                audio.mode = AudioManager.MODE_IN_COMMUNICATION
                @Suppress("DEPRECATION")
                audio.isSpeakerphoneOn = false
            }
            else -> {
                @Suppress("DEPRECATION")
                audio.isSpeakerphoneOn = false
                audio.mode = AudioManager.MODE_NORMAL
            }
        }
    }
}
