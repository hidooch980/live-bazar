package com.molido.live_bazar

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.SystemClock
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Registers the low-power widget's screen-on refresh.
 *
 * Android 8+ no longer delivers ACTION_USER_PRESENT to manifest
 * receivers, so this is a runtime receiver: it works whenever the app's
 * process is alive (which the 15-minute worker and every widget update
 * keep bringing back), and is best-effort otherwise — the periodic worker
 * remains the guarantee.
 */
class MolidoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ContextCompat.registerReceiver(
            this,
            ScreenOnReceiver(),
            IntentFilter(Intent.ACTION_USER_PRESENT),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }
}

class ScreenOnReceiver : BroadcastReceiver() {
    companion object {
        /** Native-side throttle; the Dart refresher applies its own too. */
        private const val MIN_GAP_MS = 2 * 60 * 1000L
        private var lastAt = 0L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = HomeWidgetPlugin.getData(context)
        if (prefs.getString("cfg_enabled", null) != "1") return
        // Live mode refreshes on its own ticks.
        if (prefs.getString("cfg_mode", null) == "live" && WidgetLiveService.running) return
        if (!MolidoWidgets.anyInstalled(context)) return
        val now = SystemClock.elapsedRealtime()
        if (lastAt != 0L && now - lastAt < MIN_GAP_MS) return
        lastAt = now
        WidgetLiveService.requestRefresh(context, "screen_on")
    }
}
