package com.swipelab.keyboard_height

import android.app.Activity
import androidx.annotation.NonNull
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

/**
 * Android implementation mirroring the app's original MainActivity logic:
 * - Uses WindowInsetsCompat.Type.ime() to get IME (keyboard) bottom inset.
 * - Emits only two events per show/hide cycle (opening -> final height, closing -> 0).
 * - Sends platform-specific animation durations (open ~260ms, close ~200ms) as originally hardcoded.
 */
class KeyboardHeightPlugin : FlutterPlugin, EventChannel.StreamHandler, ActivityAware {
    private lateinit var channel: EventChannel
    private var activity: Activity? = null
    private var events: EventChannel.EventSink? = null
    private var currentHeightDp: Float = 0f
    private var listening = false

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = EventChannel(binding.binaryMessenger, "keyboard_height_event")
        channel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
        start()
    }

    override fun onCancel(arguments: Any?) {
        stop()
        events = null
    }

    private fun start() {
        if (listening) return
        val act = activity ?: return
        val decor = act.window.decorView
        val density = act.resources.displayMetrics.density
        listening = true

        ViewCompat.setOnApplyWindowInsetsListener(decor) { _, insets ->
            val imeHeightPx = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            val imeHeightDp = imeHeightPx / density

            if (kotlin.math.abs(imeHeightDp - currentHeightDp) > 1f) {
                val isOpening = currentHeightDp == 0f && imeHeightDp > 0f
                val isClosing = currentHeightDp > 0f && imeHeightDp == 0f
                if (isOpening) {
                    events?.success(mapOf("height" to imeHeightDp.toDouble(), "duration" to 260))
                } else if (isClosing) {
                    events?.success(mapOf("height" to 0.0, "duration" to 200))
                } else {
                    events?.success(mapOf("height" to imeHeightDp.toDouble(), "duration" to 180))
                }
            }
            currentHeightDp = imeHeightDp
            insets
        }
    }

    private fun stop() {
        if (!listening) return
        val act = activity ?: return
        val decor = act.window.decorView
        ViewCompat.setOnApplyWindowInsetsListener(decor, null)
        listening = false
        currentHeightDp = 0f
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        stop(); activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        stop(); activity = null
    }
}
