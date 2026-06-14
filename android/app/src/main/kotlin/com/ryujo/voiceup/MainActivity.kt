package com.ryujo.voiceup

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts two method channels:
 *  - `voiceup/audio_route`  : speakerphone routing for the call-mode bar.
 *  - `voiceup/call_button`  : controls the accessibility floating mic button.
 */
class MainActivity : FlutterActivity() {
    private val audioChannel = "voiceup/audio_route"
    private val buttonChannel = "voiceup/call_button"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallMode" -> {
                        applyCallMode(call.argument<String>("mode") ?: "off")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, buttonChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" ->
                        result.success(isAccessibilityEnabled())
                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "getPlaybackGain" -> {
                        val gain = getSharedPreferences(
                            VoiceUpAccessibilityService.PREFS,
                            Context.MODE_PRIVATE,
                        ).getInt(
                            VoiceUpAccessibilityService.KEY_GAIN_MB,
                            VoiceUpAccessibilityService.DEFAULT_GAIN_MB,
                        )
                        result.success(gain)
                    }
                    "setPlaybackGain" -> {
                        val gain = call.argument<Int>("gainMb")
                            ?: VoiceUpAccessibilityService.DEFAULT_GAIN_MB
                        getSharedPreferences(
                            VoiceUpAccessibilityService.PREFS,
                            Context.MODE_PRIVATE,
                        ).edit()
                            .putInt(VoiceUpAccessibilityService.KEY_GAIN_MB, gain)
                            .apply()
                        result.success(null)
                    }
                    "setCallButton" -> {
                        val show = call.argument<Boolean>("show") ?: false
                        val svc = VoiceUpAccessibilityService.instance
                        if (svc == null) {
                            persistFlag(
                                VoiceUpAccessibilityService.KEY_BUTTON_ON,
                                show,
                            )
                            result.success(false)
                        } else {
                            svc.setButtonVisible(show)
                            result.success(true)
                        }
                    }
                    "setAutoMode" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val svc = VoiceUpAccessibilityService.instance
                        if (svc == null) {
                            persistFlag(VoiceUpAccessibilityService.KEY_AUTO, enabled)
                            result.success(false)
                        } else {
                            svc.setAutoMode(enabled)
                            result.success(true)
                        }
                    }
                    "isAutoEnabled" -> {
                        val on = getSharedPreferences(
                            VoiceUpAccessibilityService.PREFS,
                            Context.MODE_PRIVATE,
                        ).getBoolean(VoiceUpAccessibilityService.KEY_AUTO, false)
                        result.success(on)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Remembers a flag so the service applies it once enabled. */
    private fun persistFlag(key: String, value: Boolean) {
        getSharedPreferences(
            VoiceUpAccessibilityService.PREFS,
            Context.MODE_PRIVATE,
        ).edit().putBoolean(key, value).apply()
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = "$packageName/$packageName.VoiceUpAccessibilityService"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
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
