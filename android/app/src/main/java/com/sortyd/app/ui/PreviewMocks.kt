package com.sortyd.app.ui

import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.data.model.TaskList
import java.util.UUID

object PreviewMocks {
    val mockTasks = listOf(
        SortydTask(id = "1", title = "Morning Walk", isCompleted = true, weight = 0.25),
        SortydTask(id = "2", title = "Read for 30 mins", isCompleted = false, weight = 0.25),
        SortydTask(id = "3", title = "Drink Water", isCompleted = true, weight = 0.25),
        SortydTask(id = "4", title = "Work on Project", isCompleted = false, weight = 0.25)
    )

    val mockLists = listOf(
        TaskList(
            id = "list1",
            name = "🌅 Daily Routine",
            emoji = "🌅",
            tasks = mockTasks,
            sortOrder = 0
        ),
        TaskList(
            id = "list2",
            name = "💼 Work Tasks",
            emoji = "💼",
            tasks = listOf(
                SortydTask(id = "5", title = "Email Clients", isCompleted = false, weight = 0.5),
                SortydTask(id = "6", title = "Team Meeting", isCompleted = true, weight = 0.5)
            ),
            sortOrder = 1
        ),
        TaskList(
            id = "list3",
            name = "📦 Archived List",
            emoji = "📦",
            tasks = emptyList(),
            isArchived = true,
            sortOrder = 2
        )
    )
}
