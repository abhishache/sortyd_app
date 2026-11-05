package com.sortyd.app.services

import java.util.Calendar

object ReminderPolicy {
    fun fireTime(reminder: Long?, oneTime: Boolean, leadMinutes: Int = 0,
                 archived: Boolean = false, completed: Boolean = false,
                 now: Long = System.currentTimeMillis()): Long? {
        if (reminder == null || archived || completed) return null
        if (oneTime) {
            if (reminder <= now) return null
            val advance = reminder - leadMinutes * 60_000L
            return if (advance > now) advance else null
        }
        val original = Calendar.getInstance().apply { timeInMillis = reminder }
        val next = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, original.get(Calendar.HOUR_OF_DAY))
            set(Calendar.MINUTE, original.get(Calendar.MINUTE))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.MINUTE, -leadMinutes)
            if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
        }
        return next.timeInMillis
    }

    fun dayStart(time: Long): Long = Calendar.getInstance().apply {
        timeInMillis = time
        if (get(Calendar.HOUR_OF_DAY) < 4) add(Calendar.DAY_OF_YEAR, -1)
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis
}
