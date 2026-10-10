package com.molido.live_bazar

import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray

/**
 * Draws the three widget sizes from the payload HomeWidgetService writes.
 *
 * Everything shown comes from that payload: the native side never
 * computes, rounds or invents a price. Rows the Dart side left out (no
 * usable quote) are simply not drawn, and the «به‌روزرسانی» line is the
 * Dart side's honest oldest-shown time.
 */
object MolidoWidgetRenderer {

    data class Row(
        val label: String,
        val subtitle: String,
        val value: String,
        val unit: String,
        val change: String,
        val direction: Int,
        val glyph: String,
        val tone: String,
        val spark: List<Float>,
        val stale: Boolean,
    )

    private const val UP = 0xFF4ADE80.toInt()
    private const val DOWN = 0xFFF87171.toInt()
    private const val TEXT = 0xFFFFFFFF.toInt()
    private const val TEXT_STALE = 0xB3FFFFFF.toInt()

    fun rows(data: SharedPreferences): List<Row> {
        val raw = data.getString("w_rows", null)
        if (raw != null) {
            return try {
                val arr = JSONArray(raw)
                (0 until arr.length()).map { i ->
                    val o = arr.getJSONObject(i)
                    Row(
                        label = o.optString("l"),
                        subtitle = o.optString("s"),
                        value = o.optString("v"),
                        unit = o.optString("u"),
                        change = o.optString("c"),
                        direction = o.optInt("d"),
                        glyph = o.optString("g"),
                        tone = o.optString("t"),
                        spark = o.optString("k").split(',')
                            .mapNotNull { it.toFloatOrNull() },
                        stale = o.optInt("st") == 1,
                    )
                }
            } catch (e: Exception) {
                emptyList()
            }
        }
        // A 0.4–0.6 payload, until the app publishes the new one.
        val legacy = listOf(
            Triple("w_usd", "دلار", "$"),
            Triple("w_gold", "طلای ۱۸", "▬"),
            Triple("w_coin", "سکه امامی", "★"),
        )
        return legacy.mapNotNull { (key, label, glyph) ->
            val text = data.getString(key, null) ?: return@mapNotNull null
            val parts = text.split(' ')
            Row(label, "", parts.first(), parts.drop(1).joinToString(" "), "", 0,
                glyph, if (glyph == "$") "green" else "gold", emptyList(), false)
        }
    }

    private fun toneRes(tone: String) = when (tone) {
        "green" -> R.drawable.widget_icon_green
        "gold" -> R.drawable.widget_icon_gold
        "teal" -> R.drawable.widget_icon_teal
        "blue" -> R.drawable.widget_icon_blue
        "orange" -> R.drawable.widget_icon_orange
        "silver" -> R.drawable.widget_icon_silver
        else -> R.drawable.widget_icon_purple
    }

    private fun id(context: Context, name: String): Int =
        context.resources.getIdentifier(name, "id", context.packageName)

    private fun launch(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

    /** A small line chart of REAL observations; null with fewer than two. */
    fun sparkline(context: Context, points: List<Float>, direction: Int,
                  widthDp: Int, heightDp: Int): Bitmap? {
        if (points.size < 2) return null
        val d = context.resources.displayMetrics.density
        val w = (widthDp * d).toInt().coerceAtLeast(2)
        val h = (heightDp * d).toInt().coerceAtLeast(2)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val rising = if (direction != 0) direction > 0 else points.last() >= points.first()
        val color = if (rising) UP else DOWN
        val pad = 2 * d
        val stepX = (w - 2 * pad) / (points.size - 1)
        val line = Path()
        points.forEachIndexed { i, p ->
            // RTL widget, but time still runs left → right like every chart.
            val x = pad + i * stepX
            val y = pad + (1f - p.coerceIn(0f, 1f)) * (h - 2 * pad)
            if (i == 0) line.moveTo(x, y) else line.lineTo(x, y)
        }
        val fill = Path(line).apply {
            lineTo(pad + (points.size - 1) * stepX, h.toFloat())
            lineTo(pad, h.toFloat())
            close()
        }
        c.drawPath(fill, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, 0f, h.toFloat(),
                (color and 0x00FFFFFF) or 0x55000000, color and 0x00FFFFFF,
                Shader.TileMode.CLAMP)
        })
        c.drawPath(line, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = 1.6f * d
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        })
        return bmp
    }

    private fun bindRow(context: Context, v: RemoteViews, i: Int, row: Row,
                        sparkW: Int, sparkH: Int, withSub: Boolean) {
        v.setTextViewText(id(context, "w_icon_$i"), row.glyph)
        v.setInt(id(context, "w_icon_$i"), "setBackgroundResource", toneRes(row.tone))
        v.setTextViewText(id(context, "w_label_$i"), row.label)
        if (withSub) v.setTextViewText(id(context, "w_sub_$i"), row.subtitle)
        v.setTextViewText(id(context, "w_value_$i"), row.value)
        v.setTextColor(id(context, "w_value_$i"), if (row.stale) TEXT_STALE else TEXT)
        v.setTextViewText(id(context, "w_unit_$i"), row.unit)
        val pill = id(context, "w_change_$i")
        if (row.change.isEmpty()) {
            v.setViewVisibility(pill, View.INVISIBLE)
        } else {
            v.setViewVisibility(pill, View.VISIBLE)
            v.setTextViewText(pill, row.change)
            val up = row.direction >= 0
            v.setTextColor(pill, if (up) UP else DOWN)
            v.setInt(pill, "setBackgroundResource",
                if (up) R.drawable.widget_pill_up else R.drawable.widget_pill_down)
        }
        val spark = id(context, "w_spark_$i")
        val bmp = sparkline(context, row.spark, row.direction, sparkW, sparkH)
        if (bmp == null) {
            v.setViewVisibility(spark, View.INVISIBLE)
        } else {
            v.setViewVisibility(spark, View.VISIBLE)
            v.setImageViewBitmap(spark, bmp)
        }
    }

    private fun updated(data: SharedPreferences) =
        data.getString("w_updated", null) ?: "بدون داده"

    fun small(context: Context, data: SharedPreferences): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.molido_widget_small)
        rows(data).firstOrNull()?.let { bindRow(context, v, 0, it, 90, 26, false) }
        v.setTextViewText(R.id.widget_updated, updated(data))
        v.setOnClickPendingIntent(R.id.widget_root, launch(context))
        return v
    }

    fun medium(context: Context, data: SharedPreferences): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.molido_widget)
        val rows = rows(data)
        for (i in 0 until 3) {
            val row = rows.getOrNull(i)
            v.setViewVisibility(id(context, "w_row_$i"), if (row == null) View.INVISIBLE else View.VISIBLE)
            if (row != null) bindRow(context, v, i, row, 70, 20, false)
        }
        v.setTextViewText(R.id.widget_updated, updated(data))
        v.setOnClickPendingIntent(R.id.widget_root, launch(context))
        return v
    }

    fun large(context: Context, data: SharedPreferences): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.molido_widget_large)
        val rows = rows(data)
        for (i in 0 until 6) {
            val row = rows.getOrNull(i)
            val vis = if (row == null) View.GONE else View.VISIBLE
            v.setViewVisibility(id(context, "w_row_$i"), vis)
            if (i > 0) v.setViewVisibility(id(context, "w_div_$i"), vis)
            if (row != null) bindRow(context, v, i, row, 64, 22, true)
        }
        v.setViewVisibility(R.id.widget_live,
            if (data.getString("w_live", null) == "1") View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.widget_updated, updated(data))
        v.setOnClickPendingIntent(R.id.widget_root, launch(context))
        return v
    }
}
