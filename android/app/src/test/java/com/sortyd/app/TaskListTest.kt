package com.sortyd.app

import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.data.model.TaskList
import org.junit.Assert.*
import org.junit.Test

class TaskListTest {

    // ── helpers ──

    private fun task(
        id: String = "t1",
        completed: Boolean = false,
        weight: Double = 0.0,
        healthType: String? = null,
        healthTarget: Double? = null,
    ) = SortydTask(
        id = id,
        listId = "list1",
        title = "Task",
        isCompleted = completed,
        weight = weight,
        healthType = healthType,
        healthTarget = healthTarget,
    )

    private fun listOf(vararg tasks: SortydTask) = TaskList(
        id = "list1",
        name = "My List",
        tasks = tasks.toList(),
    )

    // ── completionFraction: empty list ──

    @Test fun fraction_emptyList() {
        val list = listOf()
        assertEquals(0.0, list.completionFraction(), 0.001)
    }

    // ── completionFraction: no weights (all weight=0, simple-count path) ──

    @Test fun fraction_noWeights_noneCompleted() {
        val list = listOf(task("t1"), task("t2"), task("t3"))
        assertEquals(0.0, list.completionFraction(), 0.001)
    }

    @Test fun fraction_noWeights_allCompleted() {
        val list = listOf(task("t1", completed = true), task("t2", completed = true))
        assertEquals(1.0, list.completionFraction(), 0.001)
    }

    @Test fun fraction_noWeights_halfCompleted() {
        val list = listOf(task("t1", completed = true), task("t2", completed = false))
        assertEquals(0.5, list.completionFraction(), 0.001)
    }

    // ── BUG: weights are never recalculated in the repo, so tasks always
    //    have weight=0 and the weight-based path is never exercised in production.
    //    These tests show what WOULD happen if weights were set correctly. ──

    @Test fun fraction_withWeights_allCompleted() {
        val list = listOf(
            task("t1", completed = true, weight = 0.5),
            task("t2", completed = true, weight = 0.5),
        )
        assertEquals(1.0, list.completionFraction(), 0.001)
    }

    @Test fun fraction_withWeights_halfCompleted() {
        val list = listOf(
            task("t1", completed = true, weight = 0.5),
            task("t2", completed = false, weight = 0.5),
        )
        assertEquals(0.5, list.completionFraction(), 0.001)
    }

    @Test fun fraction_withWeights_unequalWeights() {
        val list = listOf(
            task("t1", completed = true, weight = 0.75),
            task("t2", completed = false, weight = 0.25),
        )
        assertEquals(0.75, list.completionFraction(), 0.001)
    }

    // ── completionFraction: health tasks use partial progress ──

    @Test fun fraction_healthTask_partialProgress_withWeights() {
        val list = listOf(
            task("t1", completed = false, weight = 1.0,
                healthType = "steps", healthTarget = 10_000.0),
        )
        // 5 000 steps = 50% of target
        val healthValues = mapOf("t1" to 0.5)
        assertEquals(0.5, list.completionFraction(healthValues), 0.001)
    }

    @Test fun fraction_healthTask_fullProgress_withWeights() {
        val list = listOf(
            task("t1", completed = false, weight = 1.0,
                healthType = "steps", healthTarget = 10_000.0),
        )
        val healthValues = mapOf("t1" to 1.0)
        assertEquals(1.0, list.completionFraction(healthValues), 0.001)
    }

    @Test fun fraction_healthTask_alreadyCompleted_usesWeight() {
        val list = listOf(
            task("t1", completed = true, weight = 1.0,
                healthType = "steps", healthTarget = 10_000.0),
        )
        // When already completed, health-task branch returns the weight directly
        assertEquals(1.0, list.completionFraction(emptyMap()), 0.001)
    }

    // ── completionPercentage convenience ──

    @Test fun completionPercentage_half() {
        val list = listOf(task("t1", completed = true), task("t2"))
        assertEquals(50, list.completionPercentage)
    }

    @Test fun completionPercentage_none() {
        val list = listOf(task("t1"), task("t2"))
        assertEquals(0, list.completionPercentage)
    }

    // ── cleanName: strips leading emoji ──

    @Test fun cleanName_noEmoji() {
        val list = TaskList(name = "Morning Routine")
        assertEquals("Morning Routine", list.cleanName)
    }

    @Test fun cleanName_singleEmoji() {
        val list = TaskList(name = "🏋️ Workout")
        assertEquals("Workout", list.cleanName)
    }

    @Test fun cleanName_emojiWithSpaces() {
        val list = TaskList(name = "🧘  Meditation")
        assertEquals("Meditation", list.cleanName)
    }

    @Test fun cleanName_multipleLeadingEmojis() {
        val list = TaskList(name = "🔥💪 Gym Session")
        assertEquals("Gym Session", list.cleanName)
    }

    @Test fun cleanName_onlyEmoji() {
        // Just an emoji — cleanName should be empty string
        val list = TaskList(name = "📋")
        assertEquals("", list.cleanName)
    }

    @Test fun cleanName_emojiMidString_preserved() {
        val list = TaskList(name = "Morning ☀️ Routine")
        assertEquals("Morning ☀️ Routine", list.cleanName)
    }

    // ── withRecalculatedWeights ──

    @Test fun withRecalculatedWeights_twoTasks_equalWeights() {
        val list = listOf(task("t1"), task("t2"))
        val recalculated = TaskList.withRecalculatedWeights(list)
        assertEquals(0.5, recalculated.tasks[0].weight, 0.001)
        assertEquals(0.5, recalculated.tasks[1].weight, 0.001)
    }

    @Test fun withRecalculatedWeights_threeTasksEqualWeights() {
        val list = listOf(task("t1"), task("t2"), task("t3"))
        val recalculated = TaskList.withRecalculatedWeights(list)
        recalculated.tasks.forEach {
            assertEquals(1.0 / 3.0, it.weight, 0.001)
        }
    }

    @Test fun withRecalculatedWeights_emptyList_noOp() {
        val list = listOf()
        val recalculated = TaskList.withRecalculatedWeights(list)
        assertTrue(recalculated.tasks.isEmpty())
    }

    @Test fun withRecalculatedWeights_doesNotMutateOriginal() {
        val list = listOf(task("t1"), task("t2"))
        TaskList.withRecalculatedWeights(list)
        assertEquals(0.0, list.tasks[0].weight, 0.001)
    }
}
