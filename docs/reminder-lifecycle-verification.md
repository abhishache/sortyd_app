# Reminder and Watch lifecycle fixes

## Implemented

Expired weekly events no longer move their reminder to the present. Weekly reminders whose ten minute advance window has passed are not replayed at event start.

iOS schedules from the latest task state, serializes reconciliation, and cancels reminders for completed, removed, archived or expired tasks. Restore, undo, edits, foreground reloads and health completion update notification state. To do reminders are treated as one time regardless of legacy flags. Conflicts ignore expired, completed and archived tasks and compare dates for dated reminders.

Android maintains a reminder registry and reconciles it after repository mutations. The receiver validates the current task, list and scheduled time before notifying. Deleted or archived tasks cannot sustain repeating alarms. Undo and redo retain task identity. Reboot and app update rescheduling use the same rules.

The iOS evening notification is now a localized, generic invitation to review the day. It deliberately does not claim to contain freshly calculated statistics. Inactivity nudges refresh their referenced tasks while retaining the original delivery date.

Daily resets preserve weekly event completion. Snapshots use the logical day starting at 4 AM and retained state is attributed to its last active day, not automatically yesterday or today. iOS immediate saves finish before reload, avoiding stale reads around reset. Android resets are serialized.

Weekly reminder creation on iOS now requests notification permission. The OS can still deny permission or suppress delivery.

Watch completion sends an individual task operation, not the entire dataset. The phone rejects legacy full-store writes, duplicate operations, stale-day operations and completion conflicts. Phone-owned planner metadata remains authoritative. Offline operations use queued user info rather than an application context that replaces earlier operations.

## Verified on September 9, 2026

iOS Debug device build, including the Watch targets, succeeded with signing disabled.

Android Debug APK assembly and JVM unit tests succeeded.

The standalone Swift regression executable passed 18 assertions for expiry, completion, archive, recurrence, the 4 AM boundary and Watch completion conflicts. Five Android reminder policy test methods passed alongside the existing unit suite.

## Required before release

These are build and policy checks, not physical-device notification tests. On updated iPhone, Watch and Android installations, verify:

1. Opening the app with a seven week old event produces no notification and clears its pending reminder.
2. A future event produces one advance reminder. Reopening or editing after delivery does not replay it.
3. Completion, deletion, archive and reminder removal suppress pending alerts. Undo and restore schedule eligible future reminders again.
4. A new installation requests permission for its first weekly reminder. Test granted and denied permissions.
5. Lock the device before the reminder. Test Focus settings and Android battery restrictions separately from app logic.
6. Cross 4 AM and reopen after several days away. Confirm weekly completion is retained and old completion is not attributed to yesterday.
7. Toggle tasks from an offline Watch, reconnect, and confirm phone edits, list types, planner data, colours, durations and sounds remain intact. Test an old Watch build against the updated phone too.
8. Complete or delete a task mentioned in an inactivity nudge and confirm its pending content is refreshed or cancelled.

No store build has been uploaded or released by this work. Previously lost Watch metadata and incorrectly dated historical snapshots are not reconstructed automatically because the original values cannot be inferred safely.
