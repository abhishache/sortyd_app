package com.sortyd.app

import com.sortyd.app.data.model.DailySnapshot
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.TimeUnit

/**
 * Tests for the streak-counting algorithm extracted from SortydViewModel.calculateStreak().
 * The logic is reproduced here so it can be tested without an Android Application context.
 *
 * Algorithm: sort snapshots descending by date, count consecutive leading ones with
 * completionFraction >= 0.8.
 */
class StreakCalculationTest {

    private val DAY_MS = TimeUnit.DAYS.toMillis(1)

    /** Mirrors SortydViewModel.calculateStreak exactly. */
    private fun calculateStreak(listId: String, snapshots: List<DailySnapshot>): Int {
        val listSnaps = snapshots
            .filter { it.listId == listId }
            .sortedByDescending { it.date }
        var streak = 0
        var prevDate: Long? = null
        val oneDayMs = DAY_MS
        for (snap in listSnaps) {
            if (prevDate != null && prevDate - snap.date > oneDayMs + oneDayMs / 2) break
            if (snap.completionFraction >= 0.8) streak++ else break
            prevDate = snap.date
        }
        return streak
    }

    private fun snap(daysAgo: Long, fraction: Double, listId: String = "list1") = DailySnapshot(
        date = System.currentTimeMillis() - daysAgo * DAY_MS,
        listId = listId,
        completionFraction = fraction,
    )

    // ── basic cases ──

    @Test fun streak_empty() = assertEquals(0, calculateStreak("list1", emptyList()))

    @Test fun streak_noSnapshotsForList() {
        val snaps = listOf(snap(0, 1.0, listId = "other"))
        assertEquals(0, calculateStreak("list1", snaps))
    }

    @Test fun streak_todayOnly_above80() {
        assertEquals(1, calculateStreak("list1", listOf(snap(0, 1.0))))
    }

    @Test fun streak_todayOnly_below80() {
        assertEquals(0, calculateStreak("list1", listOf(snap(0, 0.7))))
    }

    @Test fun streak_exactly80_counts() {
        assertEquals(1, calculateStreak("list1", listOf(snap(0, 0.8))))
    }

    @Test fun streak_threeDays_allAbove80() {
        val snaps = listOf(snap(0, 1.0), snap(1, 0.9), snap(2, 0.8))
        assertEquals(3, calculateStreak("list1", snaps))
    }

    @Test fun streak_breakInMiddle_countsStopped() {
        // Day 0=100%, day 1=50% (break), day 2=100% — streak should be 1
        val snaps = listOf(snap(0, 1.0), snap(1, 0.5), snap(2, 1.0))
        assertEquals(1, calculateStreak("list1", snaps))
    }

    @Test fun streak_firstDayBelow80() {
        val snaps = listOf(snap(0, 0.5), snap(1, 1.0), snap(2, 1.0))
        assertEquals(0, calculateStreak("list1", snaps))
    }

    // ── Date continuity: gaps must break the streak ──

    @Test fun gappedDays_countOnlyConsecutive() {
        // Today and 5 days ago — should be streak 1, not 2.
        val snaps = listOf(snap(0, 1.0), snap(5, 1.0))
        assertEquals(1, calculateStreak("list1", snaps))
    }

    @Test fun consecutiveDays_noGap() {
        val snaps = listOf(snap(0, 1.0), snap(1, 1.0), snap(2, 1.0))
        assertEquals(3, calculateStreak("list1", snaps))
    }

    // ── multiple lists filtered correctly ──

    @Test fun streak_multipleListsFiltered() {
        val snaps = listOf(
            snap(0, 1.0, "list1"),
            snap(1, 1.0, "list1"),
            snap(0, 0.0, "list2"),
        )
        assertEquals(2, calculateStreak("list1", snaps))
        assertEquals(0, calculateStreak("list2", snaps))
    }
}
