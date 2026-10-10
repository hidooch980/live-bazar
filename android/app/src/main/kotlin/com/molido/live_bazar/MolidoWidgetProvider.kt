package com.molido.live_bazar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget, three sizes, one payload.
 *
 * Values are written by the Dart side (HomeWidgetService) into the shared
 * preferences home_widget owns. The widget renders whatever was last
 * written and always shows its own timestamp, so a stale widget announces
 * that it is stale instead of pretending to be live.
 */
abstract class MolidoBaseWidgetProvider : HomeWidgetProvider() {
    abstract fun build(context: Context, data: SharedPreferences): RemoteViews

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(widgetId, build(context, widgetData))
        }
    }

    /** The last widget of this size was removed. */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        if (!MolidoWidgets.anyInstalled(context)) WidgetLiveService.stop(context)
    }
}

/** Medium (4×2): the first three assets. Keeps the 0.4.0 class name so
 *  widgets users already placed survive the upgrade. */
class MolidoWidgetProvider : MolidoBaseWidgetProvider() {
    override fun build(context: Context, data: SharedPreferences) =
        MolidoWidgetRenderer.medium(context, data)
}

/** Small (2×2): the first asset. */
class MolidoWidgetSmallProvider : MolidoBaseWidgetProvider() {
    override fun build(context: Context, data: SharedPreferences) =
        MolidoWidgetRenderer.small(context, data)
}

/** Large (4×4): up to six assets with sparklines. */
class MolidoWidgetLargeProvider : MolidoBaseWidgetProvider() {
    override fun build(context: Context, data: SharedPreferences) =
        MolidoWidgetRenderer.large(context, data)
}

object MolidoWidgets {
    private val providers = listOf(
        MolidoWidgetSmallProvider::class.java,
        MolidoWidgetProvider::class.java,
        MolidoWidgetLargeProvider::class.java,
    )

    fun anyInstalled(context: Context): Boolean {
        val mgr = AppWidgetManager.getInstance(context)
        return providers.any {
            mgr.getAppWidgetIds(ComponentName(context, it)).isNotEmpty()
        }
    }
}
