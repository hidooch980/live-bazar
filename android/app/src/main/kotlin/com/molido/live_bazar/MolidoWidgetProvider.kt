package com.molido.live_bazar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.SharedPreferences

/**
 * Home screen widget: the prices, without opening the app.
 *
 * Values are written by the Dart side (HomeWidgetService) into the shared
 * preferences home_widget owns, and refreshed by the same background
 * worker that evaluates price alerts. The widget renders whatever was
 * last written and always shows its own timestamp, so a stale widget
 * announces that it is stale instead of pretending to be live.
 */
class MolidoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.molido_widget).apply {
                setTextViewText(
                    R.id.widget_usd_value,
                    widgetData.getString("w_usd", null) ?: "—",
                )
                setTextViewText(
                    R.id.widget_gold_value,
                    widgetData.getString("w_gold", null) ?: "—",
                )
                setTextViewText(
                    R.id.widget_coin_value,
                    widgetData.getString("w_coin", null) ?: "—",
                )
                setTextViewText(
                    R.id.widget_updated,
                    widgetData.getString("w_updated", null) ?: "بدون داده",
                )
                // Tapping anywhere opens the app.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
