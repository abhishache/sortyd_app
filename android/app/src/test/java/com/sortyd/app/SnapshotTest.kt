package com.sortyd.app

import com.sortyd.app.data.model.DailySnapshot
import com.sortyd.app.data.model.toDomain
import com.sortyd.app.data.model.toEntity
import org.junit.Assert.*
import org.junit.Test

class SnapshotTest {

    // ── toEntity / toDomain roundtrip ──

    @Test fun roundtrip_noIds() {
        val snap = DailySnapshot(
            id = "snap1",
            date = 1_000_000L,
            listId = "list1",
            completionFraction = 0.75,
            completedTaskIds = emptyList(),
        )
        val entity = snap.toEntity()
        val domain = entity.toDomain()
        assertEquals(snap.id, domain.id)
        assertEquals(snap.date, domain.date)
        assertEquals(snap.listId, domain.listId)
        assertEquals(snap.completionFraction, domain.completionFraction, 0.001)
        assertTrue(domain.completedTaskIds.isEmpty())
    }

    @Test fun roundtrip_singleId() {
        val snap = DailySnapshot(
            id = "snap2",
            date = 2_000_000L,
            listId = "list2",
            completionFraction = 1.0,
            completedTaskIds = listOf("task-uuid-123"),
        )
        val domain = snap.toEntity().toDomain()
        assertEquals(listOf("task-uuid-123"), domain.completedTaskIds)
    }

    @Test fun roundtrip_multipleIds() {
        val ids = listOf("a", "b", "c")
        val snap = DailySnapshot(
            id = "snap3", date = 0L, listId = "l1",
            completionFraction = 0.33,
            completedTaskIds = ids,
        )
        val domain = snap.toEntity().toDomain()
        assertEquals(ids, domain.completedTaskIds)
    }

    @Test fun roundtrip_uuidIds() {
        val ids = listOf(
            "550e8400-e29b-41d4-a716-446655440000",
            "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
        )
        val snap = DailySnapshot(
            id = "snap4", date = 0L, listId = "l1",
            completionFraction = 0.5,
            completedTaskIds = ids,
        )
        val domain = snap.toEntity().toDomain()
        assertEquals(ids, domain.completedTaskIds)
    }

    // ── toEntity: JSON encoding ──

    @Test fun toEntity_emptyIds_producesEmptyJsonArray() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l", completionFraction = 0.0)
        val entity = snap.toEntity()
        assertEquals("[]", entity.completedTaskIds)
    }

    @Test fun toEntity_singleId_producesQuotedEntry() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l",
            completionFraction = 0.0, completedTaskIds = listOf("abc"))
        val entity = snap.toEntity()
        assertEquals("[\"abc\"]", entity.completedTaskIds)
    }

    @Test fun toEntity_multipleIds_producesCommaSeparated() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l",
            completionFraction = 0.0, completedTaskIds = listOf("x", "y"))
        val entity = snap.toEntity()
        assertEquals("[\"x\",\"y\"]", entity.completedTaskIds)
    }

    // ── completionPercentage convenience ──

    @Test fun completionPercentage_zero() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l", completionFraction = 0.0)
        assertEquals(0, snap.completionPercentage)
    }

    @Test fun completionPercentage_full() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l", completionFraction = 1.0)
        assertEquals(100, snap.completionPercentage)
    }

    @Test fun completionPercentage_partial() {
        val snap = DailySnapshot(id = "s", date = 0L, listId = "l", completionFraction = 0.75)
        assertEquals(75, snap.completionPercentage)
    }
}
