# Date and history reliability fixes

Confirmed and corrected following the weekly calendar weekday report:

1. iOS historical day sheets wrote snapshots on dismissal even when editing was disabled. Scores were recalculated from the current task count, potentially exceeding 100 percent or dividing by zero after tasks were deleted. Normal viewing and blocked edit attempts now preserve saved history; displayed percentages use the saved snapshot. Debug editing only saves a changed selection against a nonempty task list.
2. iOS best streaks, including values exported to widgets, counted across absent dates. HistoryPolicy now requires consecutive local calendar dates and counts a duplicated date only once.
3. iOS logical day used four elapsed hours after midnight. Daylight saving transitions made this differ from the specified 4 AM reset. It now uses 4 AM local wall time.
4. Android historical task groups included today's completion flags. They now use only the selected day's snapshot.
5. Android heatmaps overlaid live progress on the civil date before 4 AM, although persistence still belonged to the previous logical day. The overlay now uses the same logical day as persistence.
6. iOS heatmap cache observation missed score changes when snapshot identity and completed count stayed unchanged. It now observes dates, scores and completed IDs as well.

Validation: 16 new history and daylight saving assertions passed, plus 18 existing reminder and Watch conflict assertions. Swift parsing passed for the modified history view, persistence and view model. The preceding calendar suite passed 1,681 assertions.

Android `:app:testDebugUnitTest :app:compileDebugKotlin` completed successfully after fetching the missing dependencies.

The earlier Watch icon build failure was caused by passing an iPhone SDK override to the whole project. With that override removed, the build passed asset compilation, but later failed because the disk filled. Temporary artifacts created for that build were removed. A complete iOS build remains required before release.

Saved snapshots lack historical task titles and a full historical task roster. These fixes preserve recorded scores and completion IDs but cannot reconstruct deleted task names or repair history already overwritten by an older version. No release was uploaded during this audit.
