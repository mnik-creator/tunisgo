// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
package com.tunisgo.tunis_go

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar
import java.util.TimeZone

/**
 * Home-screen widget: the next departures of the user's favourite trains.
 *
 * The Flutter side (`lib/features/widget/home_widget_service.dart`) stores every
 * favourite as {number, from, to, dep (minutes), days (bit0 = Mon … bit6 = Sun)}.
 * The next departures are picked here, in Tunis time, so the widget stays
 * right while the app is closed. It refreshes every 30 min and right after
 * the first train shown has left.
 */
class NextTrainWidgetProvider : HomeWidgetProvider() {

    private data class Next(
        val number: String,
        val from: String,
        val to: String,
        val dep: Int,
        val daysAhead: Int,
        val weekday: Int,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Calendar.getInstance(TUNIS)
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val today = mondayBased(now)
        val upcoming = nextDepartures(widgetData.getString(KEY_TRAINS, null), today, nowMinutes)

        val title = widgetData.getString(KEY_TITLE, null)
        val empty = widgetData.getString(KEY_EMPTY, null)
        val tomorrow = widgetData.getString(KEY_TOMORROW, null) ?: "+1"
        val dayNames = widgetData.getString(KEY_DAY_NAMES, null)?.split(',')

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_train_widget)
            title?.let { views.setTextViewText(R.id.widget_title, it) }
            empty?.let { views.setTextViewText(R.id.widget_empty, it) }
            views.setViewVisibility(
                R.id.widget_empty,
                if (upcoming.isEmpty()) View.VISIBLE else View.GONE,
            )

            ROWS.forEachIndexed { i, row ->
                val next = upcoming.getOrNull(i)
                if (next == null) {
                    views.setViewVisibility(row, View.GONE)
                    return@forEachIndexed
                }
                views.setViewVisibility(row, View.VISIBLE)
                views.setTextViewText(TIMES[i], hhmm(next.dep))
                views.setTextViewText(ROUTES[i], "${next.from} → ${next.to}")
                val day = when (next.daysAhead) {
                    0 -> null
                    1 -> tomorrow
                    else -> dayNames?.getOrNull(next.weekday)
                }
                views.setTextViewText(
                    METAS[i],
                    listOfNotNull("N° ${next.number}", day).joinToString(" · "),
                )
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, views)
        }

        upcoming.firstOrNull()?.let { scheduleAfter(context, it, now) }
    }

    private fun nextDepartures(json: String?, today: Int, nowMinutes: Int): List<Next> {
        if (json.isNullOrEmpty()) return emptyList()
        val list = mutableListOf<Next>()
        val arr = try { JSONArray(json) } catch (e: Exception) { return emptyList() }
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val dep = o.optInt("dep", -1)
            val days = o.optInt("days", 0x7F)
            if (dep < 0 || days == 0) continue
            for (ahead in 0..7) {
                val weekday = (today + ahead) % 7
                if (days and (1 shl weekday) == 0) continue
                if (ahead == 0 && dep <= nowMinutes) continue
                list += Next(
                    number = o.optString("number"),
                    from = o.optString("from"),
                    to = o.optString("to"),
                    dep = dep,
                    daysAhead = ahead,
                    weekday = weekday,
                )
                break
            }
        }
        return list.sortedWith(compareBy({ it.daysAhead }, { it.dep })).take(ROWS.size)
    }

    /** Redraw one minute after the first train shown has left (inexact, no permission needed). */
    private fun scheduleAfter(context: Context, next: Next, now: Calendar) {
        val at = (now.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, next.daysAhead)
            set(Calendar.HOUR_OF_DAY, next.dep / 60)
            set(Calendar.MINUTE, next.dep % 60 + 1)
            set(Calendar.SECOND, 0)
        }
        val ids = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, NextTrainWidgetProvider::class.java))
        val intent = Intent(context, NextTrainWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pending = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.set(AlarmManager.RTC, at.timeInMillis, pending)
    }

    private fun mondayBased(c: Calendar): Int = (c.get(Calendar.DAY_OF_WEEK) + 5) % 7

    private fun hhmm(minutes: Int): String {
        val m = minutes % (24 * 60)
        return "%02d:%02d".format(m / 60, m % 60)
    }

    companion object {
        private val TUNIS: TimeZone = TimeZone.getTimeZone("Africa/Tunis")
        private const val KEY_TRAINS = "widget_trains"
        private const val KEY_TITLE = "widget_title"
        private const val KEY_EMPTY = "widget_empty"
        private const val KEY_TOMORROW = "widget_tomorrow"
        private const val KEY_DAY_NAMES = "widget_day_names"
        private val ROWS = listOf(R.id.row0, R.id.row1, R.id.row2)
        private val TIMES = listOf(R.id.time_0, R.id.time_1, R.id.time_2)
        private val ROUTES = listOf(R.id.route_0, R.id.route_1, R.id.route_2)
        private val METAS = listOf(R.id.meta_0, R.id.meta_1, R.id.meta_2)
    }
}
