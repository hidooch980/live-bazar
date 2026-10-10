package com.molido.live_bazar

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Opt-in «زنده» widget mode: a foreground service (type dataSync, with the
 * persistent notification Android requires) that asks the Dart side to
 * refresh the widget every [TICK_MS].
 *
 * The Dart refresher calls each provider no more often than its own
 * minimum interval (TGJU 5 s, crypto 30 s, FX 60 s), so a tick inside a
 * provider's window reuses its last real quote with its original time.
 * Ticks are skipped while the screen is off: nobody is looking at the
 * widget, and the next unlock brings it current within one tick.
 */
class WidgetLiveService : Service() {

    companion object {
        private const val TAG = "WidgetLiveService"
        const val CHANNEL_ID = "molido_widget_live"
        const val NOTIFICATION_ID = 0x4d4c
        const val ACTION_STOP = "com.molido.live_bazar.WIDGET_LIVE_STOP"
        const val TICK_MS = 10_000L

        /** Set when the user taps «توقف» so the app does not restart it. */
        const val STOPPED_BY_USER_KEY = "live_stopped_by_user"

        @Volatile
        var running = false
            private set

        fun start(context: Context) {
            ContextCompat.startForegroundService(
                context, Intent(context, WidgetLiveService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WidgetLiveService::class.java))
        }

        fun requestRefresh(context: Context, reason: String) {
            try {
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("molido://widget/refresh?reason=$reason")).send()
            } catch (e: Exception) {
                Log.w(TAG, "refresh request failed", e)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (pm.isInteractive) requestRefresh(this@WidgetLiveService, "live")
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            HomeWidgetPlugin.getData(this).edit()
                .putString(STOPPED_BY_USER_KEY, "1")
                .putString("cfg_mode", "lowPower")
                .putString("w_live", "0")
                .apply()
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            } else 0
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(), type)
        } catch (e: Exception) {
            // Android 12+ refuses a foreground start from the background
            // (e.g. a sticky restart). Stop honestly instead of crashing.
            Log.w(TAG, "cannot start in foreground", e)
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            handler.post(tick)
        }
        return START_STICKY
    }

    /** Android 15 caps dataSync services at 6 h a day. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.i(TAG, "dataSync time limit reached; stopping")
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        running = false
        super.onDestroy()
    }

    private fun notification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "ویجت زنده",
                    NotificationManager.IMPORTANCE_LOW).apply {
                    description = "اعلان دائمی حالت «زنده» ویجت صفحه اصلی"
                    setShowBadge(false)
                })
        }
        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE else 0
        val stop = PendingIntent.getService(this, 1,
            Intent(this, WidgetLiveService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable)
        val open = PendingIntent.getActivity(this, 2,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_molido)
            .setContentTitle("ویجت زنده مولیدو")
            .setContentText("قیمت‌های ویجت هر چند ثانیه به‌روز می‌شود؛ با صفحه خاموش متوقف است.")
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .addAction(0, "توقف", stop)
            .build()
    }
}
