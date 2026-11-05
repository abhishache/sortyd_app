package com.sortyd.app

import com.sortyd.app.services.ReminderPolicy
import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar

class ReminderPolicyTest {
    private val now = Calendar.getInstance().apply {
        set(2026, Calendar.SEPTEMBER, 9, 12, 0, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    @Test fun expiredEventsNeverReappear() {
        assertNull(ReminderPolicy.fireTime(now - 49L * 86_400_000, true, 10, now = now))
        assertNull(ReminderPolicy.fireTime(now, true, now = now))
        assertNull(ReminderPolicy.fireTime(null, true, now = now))
    }
    @Test fun completedAndArchivedTasksCannotNotify() {
        assertNull(ReminderPolicy.fireTime(now + 3_600_000, true, completed = true, now = now))
        assertNull(ReminderPolicy.fireTime(now + 3_600_000, true, archived = true, now = now))
    }
    @Test fun advanceReminderIsNeverReplayedAtEventStart() {
        assertEquals(now + 3_000_000, ReminderPolicy.fireTime(now + 3_600_000, true, 10, now = now))
        assertNull(ReminderPolicy.fireTime(now + 300_000, true, 10, now = now))
        assertNull(ReminderPolicy.fireTime(now + 600_000, true, 10, now = now))
    }
    @Test fun recurringReminderUsesNextOccurrence() {
        assertEquals(now + 23 * 3_600_000L, ReminderPolicy.fireTime(now - 3_600_000, false, now = now))
    }
    @Test fun logicalDayChangesAtFourNotMidnight() {
        val boundary = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 4)
        }.timeInMillis
        val day = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
        }
        assertEquals(day.timeInMillis, ReminderPolicy.dayStart(boundary))
        day.add(Calendar.DAY_OF_YEAR, -1)
        assertEquals(day.timeInMillis, ReminderPolicy.dayStart(boundary - 1))
    }
}
