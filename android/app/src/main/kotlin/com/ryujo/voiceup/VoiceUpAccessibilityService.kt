package com.ryujo.voiceup

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.TextView
import java.io.File

/**
 * Renders a floating round microphone button as a TYPE_ACCESSIBILITY_OVERLAY,
 * which — unlike a normal SYSTEM_ALERT_WINDOW overlay — keeps receiving touch
 * events even over the phone's in-call screen.
 *
 * Press and hold the button to record; release to play the clip back loudly.
 * On speakerphone the call microphone picks up the playback and the other
 * party hears the user's amplified voice.
 *
 * The recording/playback is done natively here because the overlay lives
 * outside the Flutter view hierarchy.
 */
class VoiceUpAccessibilityService : AccessibilityService() {

    companion object {
        /** Live reference so [MainActivity] can toggle the button. */
        var instance: VoiceUpAccessibilityService? = null

        const val PREFS = "voiceup"
        const val KEY_BUTTON_ON = "call_button_on"
    }

    private enum class State { IDLE, RECORDING, PLAYING }

    private var buttonView: TextView? = null
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null
    private var enhancer: LoudnessEnhancer? = null
    private var outputPath: String = ""
    private var state: State = State.IDLE

    /** Extra playback gain in millibels (+25 dB) to lift a soft voice. */
    private val playbackGainMb = 2500

    // --- lifecycle ---------------------------------------------------------

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val on = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_BUTTON_ON, false)
        if (on) showButton()
    }

    override fun onDestroy() {
        hideButton()
        cleanupRecorder()
        releasePlayer()
        instance = null
        super.onDestroy()
    }

    private fun releasePlayer() {
        try {
            enhancer?.release()
        } catch (_: Exception) {
        }
        enhancer = null
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // --- public control (called from MainActivity) -------------------------

    fun setButtonVisible(visible: Boolean) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_BUTTON_ON, visible).apply()
        if (visible) showButton() else hideButton()
    }

    // --- floating button ---------------------------------------------------

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun showButton() {
        if (buttonView != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val view = TextView(this).apply {
            gravity = Gravity.CENTER
            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> startRecording()
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> stopAndPlay()
                }
                true
            }
        }
        buttonView = view
        applyState(State.IDLE)

        val size = dp(72)
        val params = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            x = dp(12)
        }
        wm.addView(view, params)
    }

    private fun hideButton() {
        buttonView?.let {
            try {
                (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it)
            } catch (_: Exception) {
            }
        }
        buttonView = null
    }

    private fun applyState(newState: State) {
        state = newState
        val (color, label) = when (newState) {
            State.IDLE -> Color.parseColor("#6750A4") to "🎤" // 🎤
            State.RECORDING -> Color.parseColor("#D32F2F") to "●" // ●
            State.PLAYING -> Color.parseColor("#2E7D32") to "🔊" // 🔊
        }
        buttonView?.apply {
            text = label
            textSize = 26f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(color)
            }
        }
    }

    // --- record / play -----------------------------------------------------

    private fun startRecording() {
        if (state != State.IDLE) return
        try {
            val file = File(cacheDir, "voiceup_call.m4a")
            outputPath = file.absolutePath
            val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            rec.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(outputPath)
                prepare()
                start()
            }
            recorder = rec
            applyState(State.RECORDING)
        } catch (_: Exception) {
            // Mic unavailable (permission denied or busy during a call).
            cleanupRecorder()
            applyState(State.IDLE)
        }
    }

    private fun stopAndPlay() {
        val rec = recorder
        if (rec == null) {
            applyState(State.IDLE)
            return
        }
        try {
            rec.stop()
        } catch (_: Exception) {
        }
        cleanupRecorder()
        playFile(outputPath)
    }

    private fun cleanupRecorder() {
        try {
            recorder?.reset()
            recorder?.release()
        } catch (_: Exception) {
        }
        recorder = null
    }

    private fun playFile(path: String) {
        try {
            // Make sure media playback is at full volume so it carries to the
            // call mic on speakerphone.
            val audio = getSystemService(AUDIO_SERVICE) as AudioManager
            audio.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                0,
            )
            releasePlayer()
            val mp = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                setDataSource(path)
                setVolume(1f, 1f)
                prepare()
            }
            // Boost a soft recording well beyond the raw level so it survives
            // the call's echo cancellation when picked up on speakerphone.
            try {
                enhancer = LoudnessEnhancer(mp.audioSessionId).apply {
                    setTargetGain(playbackGainMb)
                    enabled = true
                }
            } catch (_: Exception) {
            }
            mp.setOnCompletionListener {
                applyState(State.IDLE)
                releasePlayer()
            }
            mp.start()
            player = mp
            applyState(State.PLAYING)
        } catch (_: Exception) {
            applyState(State.IDLE)
        }
    }
}
