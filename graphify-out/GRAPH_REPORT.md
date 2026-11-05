# Graph Report - /Users/abhishek/Desktop/sortyd  (2026-11-05)

## Corpus Check
- Large corpus: 289 files · ~515,723 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 2010 nodes · 4558 edges · 79 communities detected
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 374 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Website features and coaching|Website features and coaching]]
- [[_COMMUNITY_iOS list and coach views|iOS list and coach views]]
- [[_COMMUNITY_Brand and launcher assets|Brand and launcher assets]]
- [[_COMMUNITY_Daily state and persistence|Daily state and persistence]]
- [[_COMMUNITY_Website learning and comparisons|Website learning and comparisons]]
- [[_COMMUNITY_AI models and response contracts|AI models and response contracts]]
- [[_COMMUNITY_Shared models and Watch sync|Shared models and Watch sync]]
- [[_COMMUNITY_Home Screen widgets|Home Screen widgets]]
- [[_COMMUNITY_Weekly planner and telemetry|Weekly planner and telemetry]]
- [[_COMMUNITY_Safety and review regressions|Safety and review regressions]]
- [[_COMMUNITY_Android list management|Android list management]]
- [[_COMMUNITY_Theme and onboarding|Theme and onboarding]]
- [[_COMMUNITY_AI starter list editing|AI starter list editing]]
- [[_COMMUNITY_Health task regression tests|Health task regression tests]]
- [[_COMMUNITY_iOS behavioural analytics|iOS behavioural analytics]]
- [[_COMMUNITY_Notification lifecycle|Notification lifecycle]]
- [[_COMMUNITY_Android data access|Android data access]]
- [[_COMMUNITY_Localization tooling and tests|Localization tooling and tests]]
- [[_COMMUNITY_Preferences and AI server|Preferences and AI server]]
- [[_COMMUNITY_Android repository operations|Android repository operations]]
- [[_COMMUNITY_Task list regression tests|Task list regression tests]]
- [[_COMMUNITY_HealthKit integration|HealthKit integration]]
- [[_COMMUNITY_Android analytics screens|Android analytics screens]]
- [[_COMMUNITY_Widget visual utilities|Widget visual utilities]]
- [[_COMMUNITY_Streak regression tests|Streak regression tests]]
- [[_COMMUNITY_Crash investigation evidence|Crash investigation evidence]]
- [[_COMMUNITY_Calendar and history evidence|Calendar and history evidence]]
- [[_COMMUNITY_Android weekly planner|Android weekly planner]]
- [[_COMMUNITY_Android home screen|Android home screen]]
- [[_COMMUNITY_Android onboarding|Android onboarding]]
- [[_COMMUNITY_Snapshot regression tests|Snapshot regression tests]]
- [[_COMMUNITY_Android list picker|Android list picker]]
- [[_COMMUNITY_Release verification and localization|Release verification and localization]]
- [[_COMMUNITY_Android domain models|Android domain models]]
- [[_COMMUNITY_Watch design mockups|Watch design mockups]]
- [[_COMMUNITY_Android localization|Android localization]]
- [[_COMMUNITY_Android AI coach|Android AI coach]]
- [[_COMMUNITY_Habit heatmap calendar|Habit heatmap calendar]]
- [[_COMMUNITY_Translated review prompt evidence|Translated review prompt evidence]]
- [[_COMMUNITY_App interface mockups|App interface mockups]]
- [[_COMMUNITY_Notification sounds|Notification sounds]]
- [[_COMMUNITY_Reminder regression tests|Reminder regression tests]]
- [[_COMMUNITY_Large Android widget|Large Android widget]]
- [[_COMMUNITY_Android Health Connect|Android Health Connect]]
- [[_COMMUNITY_Android AI list creation|Android AI list creation]]
- [[_COMMUNITY_Android main activity|Android main activity]]
- [[_COMMUNITY_Medium Android widget|Medium Android widget]]
- [[_COMMUNITY_Android task details|Android task details]]
- [[_COMMUNITY_Android widget updates|Android widget updates]]
- [[_COMMUNITY_Android heatmap widget|Android heatmap widget]]
- [[_COMMUNITY_Android Room database|Android Room database]]
- [[_COMMUNITY_Device usage monitoring|Device usage monitoring]]
- [[_COMMUNITY_Project memory and guidance|Project memory and guidance]]
- [[_COMMUNITY_Android application lifecycle|Android application lifecycle]]
- [[_COMMUNITY_Completion protection popup|Completion protection popup]]
- [[_COMMUNITY_Android theme palette|Android theme palette]]
- [[_COMMUNITY_Android typography|Android typography]]
- [[_COMMUNITY_Android compact widget|Android compact widget]]
- [[_COMMUNITY_Android navigation|Android navigation]]
- [[_COMMUNITY_Reminder delivery|Reminder delivery]]
- [[_COMMUNITY_Website crawler directives|Website crawler directives]]
- [[_COMMUNITY_Website language switching|Website language switching]]
- [[_COMMUNITY_Java HMAC verification|Java HMAC verification]]
- [[_COMMUNITY_Java signing verification|Java signing verification]]
- [[_COMMUNITY_Android launch screen|Android launch screen]]
- [[_COMMUNITY_Daily transition overlay|Daily transition overlay]]
- [[_COMMUNITY_Reminder rescheduling|Reminder rescheduling]]
- [[_COMMUNITY_Kotlin HMAC verification|Kotlin HMAC verification]]
- [[_COMMUNITY_Preview fixtures|Preview fixtures]]
- [[_COMMUNITY_Day detail sheet|Day detail sheet]]
- [[_COMMUNITY_Widget broadcasts|Widget broadcasts]]
- [[_COMMUNITY_App Store submission proof|App Store submission proof]]
- [[_COMMUNITY_Watch bridging header|Watch bridging header]]
- [[_COMMUNITY_Android root build|Android root build]]
- [[_COMMUNITY_Android shape tokens|Android shape tokens]]
- [[_COMMUNITY_Android color tokens|Android color tokens]]
- [[_COMMUNITY_Android project settings|Android project settings]]
- [[_COMMUNITY_Android application build|Android application build]]
- [[_COMMUNITY_Android shared components|Android shared components]]

## God Nodes (most connected - your core abstractions)
1. `AppViewModel` - 57 edges
2. `ios/Sortyd/ViewModels/AppViewModel.swift` - 57 edges
3. `ios/Sortyd/Views/ListManagementView.swift` - 56 edges
4. `android/app/src/main/java/com/sortyd/app/viewmodel/SortydViewModel.kt` - 50 edges
5. `ios/Sortyd/AI/AICoach.swift` - 49 edges
6. `SortydViewModel` - 46 edges
7. `ios/Sortyd/Views/AICoachView.swift` - 45 edges
8. `HealthTaskTypeTest` - 42 edges
9. `android/app/src/test/java/com/sortyd/app/HealthTaskTypeTest.kt` - 42 edges
10. `AICoach` - 40 edges

## Surprising Connections (you probably didn't know these)
- `AppLanguage` --case_of--> `english`  [EXTRACTED]
  android/app/src/main/java/com/sortyd/app/data/model/Models.kt → ios/Sortyd/Models/Models.swift
- `AppLanguage` --case_of--> `spanish`  [EXTRACTED]
  android/app/src/main/java/com/sortyd/app/data/model/Models.kt → ios/Sortyd/Models/Models.swift
- `AppLanguage` --case_of--> `arabic`  [EXTRACTED]
  android/app/src/main/java/com/sortyd/app/data/model/Models.kt → ios/Sortyd/Models/Models.swift
- `AppLanguage` --case_of--> `chinese`  [EXTRACTED]
  android/app/src/main/java/com/sortyd/app/data/model/Models.kt → ios/Sortyd/Models/Models.swift
- `object()` --calls--> `Keys`  [INFERRED]
  cloudflare/sortyd-proxy/worker.js → android/app/src/main/java/com/sortyd/app/data/preferences/UserPreferences.kt

## Hyperedges (group relationships)
- **Effective AI coaching principles** — concept_ai_coaching, concept_data_grounding, concept_actionable_feedback, concept_uncertainty_awareness [EXTRACTED 1.00]
- **Crash repair dependency hardening** — concept_review_prompt, concept_stable_task_identity, concept_completion_validation, concept_crashlytics [EXTRACTED 1.00]

## Communities

### Community 0 - "Website features and coaching"
Cohesion: 0.02
Nodes (237): Blog Post 3: ADHD, Anxiety & Bad Habits, SEO Blog Post 1: Habit Tracking, Cue routine reward loop, Self goal analysis, Ar, Privacy, Support, Adhd Anxiety Habits (+229 more)

### Community 1 - "iOS list and coach views"
Cohesion: 0.03
Nodes (107): AboutPrivacySheet, AICoachView, AnalysisState, done, failed, idle, loading, BracketCard (+99 more)

### Community 2 - "Brand and launcher assets"
Cohesion: 0.01
Nodes (73): Sortyd brand assets, android/app/src/main/ic_launcher-playstore.png, android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.webp, android/app/src/main/res/mipmap-hdpi/ic_launcher_round.webp, android/app/src/main/res/mipmap-hdpi/ic_launcher.webp, android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.webp, android/app/src/main/res/mipmap-mdpi/ic_launcher_round.webp, android/app/src/main/res/mipmap-mdpi/ic_launcher.webp (+65 more)

### Community 3 - "Daily state and persistence"
Cohesion: 0.05
Nodes (37): tasks, AppViewModel, ReminderConflictInfo, android/app/src/main/java/com/sortyd/app/data/model/SnapshotEntity.kt, android/app/src/main/java/com/sortyd/app/data/model/TaskEntity.kt, android/app/src/main/java/com/sortyd/app/data/model/TaskListEntity.kt, android/app/src/main/java/com/sortyd/app/data/model/WidgetData.kt, android/app/src/main/java/com/sortyd/app/services/HealthSyncWorker.kt (+29 more)

### Community 4 - "Website learning and comparisons"
Cohesion: 0.06
Nodes (103): Actionable feedback, AI coaching, Apple Watch, Behavioural analytics, Habit education blog, Completion rate, Context stability, Daily planner (+95 more)

### Community 5 - "AI models and response contracts"
Cohesion: 0.07
Nodes (39): AICoach, AIMessage, AIRequest, AnalysisPillar, AnalysisResult, BatchBehaviouralItem, BatchProcrastinationItem, BatchWeeklyRecapItem (+31 more)

### Community 6 - "Shared models and Watch sync"
Cohesion: 0.06
Nodes (50): combine, ios/Sortyd/Models/Models.swift, ios/Sortyd/WatchSessionManager.swift, ios/SortydWatch Watch App/WatchStore.swift, Hashable, Identifiable, AppData, arabic (+42 more)

### Community 7 - "Home Screen widgets"
Cohesion: 0.06
Nodes (47): AppIntent, appintents, ios/SortydWidgetExtension/SortydWidgetBundle.swift, ios/SortydWidgetExtension/WidgetLarge.swift, ios/SortydWidgetExtension/WidgetLockScreen.swift, ios/SortydWidgetExtension/WidgetMedium.swift, ios/SortydWidgetExtension/WidgetMonthly.swift, ios/SortydWidgetExtension/WidgetMultiList.swift (+39 more)

### Community 8 - "Weekly planner and telemetry"
Cohesion: 0.05
Nodes (36): App, AppTelemetry, clarity, ContentView, updateAppearance(), ios/Sortyd/ContentView.swift, ios/Sortyd/SortydApp.swift, ios/Sortyd/Utilities/AppTelemetry.swift (+28 more)

### Community 9 - "Safety and review regressions"
Cohesion: 0.07
Nodes (23): AppTelemetry, AppLocalization, CalendarDayLabel, CalendarDayLabelTests, CompletionPolicy, CrashRegressionTests, android/app/src/main/java/com/sortyd/app/services/ReviewPromptManager.kt, ios/Sortyd/Utilities/AppLocalization.swift (+15 more)

### Community 10 - "Android list management"
Cohesion: 0.07
Nodes (6): android/app/src/main/java/com/sortyd/app/viewmodel/SortydViewModel.kt, CoachRecap, extractNumericTarget(), Pillar, ReminderConflictInfo, SortydViewModel

### Community 11 - "Theme and onboarding"
Cohesion: 0.1
Nodes (22): ios/Sortyd/Utilities/Theme.swift, ios/Sortyd/Views/OnboardingShowcaseView.swift, AdaptiveCardBase, LanguageSelectCard, OBPage, OnboardingShowcaseView, Page0Card, Page1Card (+14 more)

### Community 12 - "AI starter list editing"
Cohesion: 0.1
Nodes (18): Coordinator, HealthConflictToast, MarqueeChipRows, MarqueeRow, SmartAddTaskSheet, StarterListSheet, StarterReminderEdit, stripBannedListNameSuffixes() (+10 more)

### Community 13 - "Health task regression tests"
Cohesion: 0.09
Nodes (2): android/app/src/test/java/com/sortyd/app/HealthTaskTypeTest.kt, HealthTaskTypeTest

### Community 14 - "iOS behavioural analytics"
Cohesion: 0.11
Nodes (15): AnalyticsListPickerSheet, AnalyticsView, Array, NewUserBanner, Period, all, month, week (+7 more)

### Community 15 - "Notification lifecycle"
Cohesion: 0.13
Nodes (7): android/app/src/main/java/com/sortyd/app/services/ReminderPolicy.kt, ios/Sortyd/Utilities/NotificationManager.swift, ios/Sortyd/Utilities/ReminderPolicy.swift, ColdTaskItem, NotificationManager, ReminderPolicy, usernotifications

### Community 16 - "Android data access"
Cohesion: 0.12
Nodes (2): android/app/src/main/java/com/sortyd/app/data/db/SortydDao.kt, SortydDao

### Community 17 - "Localization tooling and tests"
Cohesion: 0.07
Nodes (20): collections, android/test_ai.py, android/test_ai_ua.py, scratch/check_translations.py, scratch/generate_clean_foreground.py, scratch/generate_foreground_svg.py, scratch/generate_light_svg.py, scratch/generate_padded_svg.py (+12 more)

### Community 18 - "Preferences and AI server"
Cohesion: 0.13
Nodes (14): send(), android/app/src/main/java/com/sortyd/app/data/preferences/UserPreferences.kt, cloudflare/sortyd-proxy/worker.js, tests/AIWorkerTests.mjs, promises, strict, Keys, UserPreferences (+6 more)

### Community 19 - "Android repository operations"
Cohesion: 0.14
Nodes (3): android/app/src/main/java/com/sortyd/app/data/repository/SortydRepository.kt, getInstance(), SortydRepository

### Community 20 - "Task list regression tests"
Cohesion: 0.15
Nodes (2): android/app/src/test/java/com/sortyd/app/TaskListTest.kt, TaskListTest

### Community 21 - "HealthKit integration"
Cohesion: 0.22
Nodes (11): CaseIterable, ios/Sortyd/Utilities/HealthKitManager.swift, DistanceUnit, kilometers, miles, HealthKitManager, HealthTaskType, calories (+3 more)

### Community 22 - "Android analytics screens"
Cohesion: 0.18
Nodes (21): AnalyticsPeriod, AnalyticsScreen(), BannerBlock(), DNABar(), DNASection(), DormancyRow(), HeroBlock(), InsightChip() (+13 more)

### Community 23 - "Widget visual utilities"
Cohesion: 0.23
Nodes (2): android/app/src/main/java/com/sortyd/app/widget/WidgetUtils.kt, WidgetUtils

### Community 24 - "Streak regression tests"
Cohesion: 0.24
Nodes (2): android/app/src/test/java/com/sortyd/app/StreakCalculationTest.kt, StreakCalculationTest

### Community 25 - "Crash investigation evidence"
Cohesion: 0.25
Nodes (16): Sortyd analytics and crash audit, Habitify's developer supplied App Store feature description, Apple benchmark methodology and definitions, Apple metric definitions, Official Firebase setup, Streaks support and recovery features, Strides help and habit state handling, docs/sortyd-analytics-crash-audit-2026-11-05.md (+8 more)

### Community 26 - "Calendar and history evidence"
Cohesion: 0.28
Nodes (16): Weekly calendar weekday correction, Date and history reliability fixes, docs/calendar-weekday-fix-2026-09-20.md, docs/history-date-audit-2026-09-20.md, 4 AM Logical Day Reset, Android Historical Task Groups, CalendarDayLabel, Consecutive Local Dates (+8 more)

### Community 27 - "Android weekly planner"
Cohesion: 0.27
Nodes (13): android/app/src/main/java/com/sortyd/app/ui/screens/home/WeeklyPlannerSection.kt, addDays(), hourLabel(), localeFor(), PlannedTaskSheet(), PlannedTaskTile(), sameDay(), sameWeek() (+5 more)

### Community 28 - "Android home screen"
Cohesion: 0.27
Nodes (13): android/app/src/main/java/com/sortyd/app/ui/screens/home/HomeScreen.kt, currentWeekNumber(), HomeEmptyState(), HomeScreen(), HomeScreenContent(), HomeScreenPreview(), OrbitalDonutPill(), TodoEmptyState() (+5 more)

### Community 29 - "Android onboarding"
Cohesion: 0.27
Nodes (13): android/app/src/main/java/com/sortyd/app/ui/screens/onboarding/OnboardingScreen.kt, AICard(), HabitsCard(), HealthCard(), HealthDisclosure(), LanguageCard(), LogoBar(), LogoHeader() (+5 more)

### Community 30 - "Snapshot regression tests"
Cohesion: 0.29
Nodes (2): android/app/src/test/java/com/sortyd/app/SnapshotTest.kt, SnapshotTest

### Community 31 - "Android list picker"
Cohesion: 0.32
Nodes (11): android/app/src/main/java/com/sortyd/app/ui/screens/lists/ListsScreen.kt, AddListBottomSheet(), FirstListHintOverlay(), HintActionPanel(), HintSpotlight(), ListCardItem(), ListsEmptyState(), ListsScreen() (+3 more)

### Community 32 - "Release verification and localization"
Cohesion: 0.32
Nodes (12): Analytics outcome telemetry, Completion value validation, Firebase Crashlytics, Firebase Analytics, Health permission sheets, Explicit language bundle lookup, App review prompt, Stable task identity (+4 more)

### Community 33 - "Android domain models"
Cohesion: 0.35
Nodes (10): android/app/src/main/java/com/sortyd/app/data/model/Models.kt, AddTask, DailyRecapData, DeleteTask, EditTask, HealthSnapshot, HealthTaskType, ReorderTasks (+2 more)

### Community 34 - "Watch design mockups"
Cohesion: 0.18
Nodes (6): ios/Sortyd_Watch_Mockups/media__1778667758887.png, ios/Sortyd_Watch_Mockups/media__1778667832583.png, ios/Sortyd_Watch_Mockups/sortyd_watch_ui_premium_analysis_1778668267039.png, ios/Sortyd_Watch_Mockups/sortyd_watch_ui_premium_list_1778667895451.png, ios/Sortyd_Watch_Mockups/sortyd_watch_ui_premium_nudge_1778668455266.png, Watch UI design mockups

### Community 35 - "Android localization"
Cohesion: 0.38
Nodes (2): android/app/src/main/java/com/sortyd/app/ui/localization/SortydStrings.kt, SortydStrings

### Community 36 - "Android AI coach"
Cohesion: 0.42
Nodes (8): CoachScreen(), OverallInsightBanner(), PillarCard(), ProcrastinationSection(), SkeletonCard(), SummaryChip(), WeeklyGradeBanner(), android/app/src/main/java/com/sortyd/app/ui/screens/coach/CoachScreen.kt

### Community 37 - "Habit heatmap calendar"
Cohesion: 0.42
Nodes (8): android/app/src/main/java/com/sortyd/app/ui/components/HeatmapCalendar.kt, getHeatColor(), HeatCell(), HeatmapCalendar(), InstallDayRingOverlay(), localeForLanguage(), localizedWeekdayInitials(), MonthPickerSheet()

### Community 38 - "Translated review prompt evidence"
Cohesion: 0.22
Nodes (5): docs/evidence/2026-11-05/review-ar.png, docs/evidence/2026-11-05/review-en-dark.png, docs/evidence/2026-11-05/review-es.png, docs/evidence/2026-11-05/review-zh.png, Review prompt localization evidence

### Community 39 - "App interface mockups"
Cohesion: 0.22
Nodes (5): ios/Sortyd_Watch_Mockups/media__1778602701244.png, ios/Sortyd_Watch_Mockups/media__1778664386657.png, ios/Sortyd_Watch_Mockups/media__1778665591136.png, ios/Sortyd_Watch_Mockups/media__1778665923937.png, App UI design mockups

### Community 40 - "Notification sounds"
Cohesion: 0.22
Nodes (4): android/app/src/main/res/raw/chime.wav, ios/Sortyd/chime.wav, ios/Sortyd/gong.wav, Notification sound assets

### Community 41 - "Reminder regression tests"
Cohesion: 0.46
Nodes (2): android/app/src/test/java/com/sortyd/app/ReminderPolicyTest.kt, ReminderPolicyTest

### Community 42 - "Large Android widget"
Cohesion: 0.46
Nodes (6): android/app/src/main/java/com/sortyd/app/widget/SortydLargeWidget.kt, HealthDialItem(), LargeWidgetContent(), SortydLargeWidget, SortydLargeWidgetReceiver, TaskLargeRow()

### Community 43 - "Android Health Connect"
Cohesion: 0.46
Nodes (5): android/app/src/main/java/com/sortyd/app/services/HealthConnectManager.kt, getAvailabilityStatus(), HealthConnectManager, isAvailable(), startHealthConnectSettings()

### Community 44 - "Android AI list creation"
Cohesion: 0.52
Nodes (6): AIStarterListScreen(), DraftTask, GeneratedListContent(), MarqueeChipRow(), TypingPlaceholder(), android/app/src/main/java/com/sortyd/app/ui/screens/lists/AIStarterListScreen.kt

### Community 45 - "Android main activity"
Cohesion: 0.52
Nodes (2): android/app/src/main/java/com/sortyd/app/MainActivity.kt, MainActivity

### Community 46 - "Medium Android widget"
Cohesion: 0.52
Nodes (5): android/app/src/main/java/com/sortyd/app/widget/SortydMediumWidget.kt, InteractiveTaskPill(), MediumWidgetContent(), SortydMediumWidget, SortydMediumWidgetReceiver

### Community 47 - "Android task details"
Cohesion: 0.6
Nodes (5): android/app/src/main/java/com/sortyd/app/ui/screens/lists/ListDetailScreen.kt, AddTaskSheet(), ListDetailScreen(), ListDiscoveryOverlay(), TaskEditBottomSheet()

### Community 48 - "Android widget updates"
Cohesion: 0.6
Nodes (2): android/app/src/main/java/com/sortyd/app/widget/WidgetManager.kt, WidgetManager

### Community 49 - "Android heatmap widget"
Cohesion: 0.6
Nodes (4): android/app/src/main/java/com/sortyd/app/widget/SortydHeatmapWidget.kt, HeatmapWidgetContent(), SortydHeatmapWidget, SortydHeatmapWidgetReceiver

### Community 50 - "Android Room database"
Cohesion: 0.6
Nodes (4): android/app/src/main/java/com/sortyd/app/data/db/SortydDatabase.kt, getInstance(), migrate(), SortydDatabase

### Community 51 - "Device usage monitoring"
Cohesion: 0.6
Nodes (2): DeviceUsageManager, android/app/src/main/java/com/sortyd/app/services/DeviceUsageManager.kt

### Community 52 - "Project memory and guidance"
Cohesion: 0.6
Nodes (5): Memory Context, First list discovery guidance, Habit Compass, App localization, Weekly plan persistence

### Community 53 - "Android application lifecycle"
Cohesion: 0.7
Nodes (2): android/app/src/main/java/com/sortyd/app/SortydApplication.kt, SortydApplication

### Community 54 - "Completion protection popup"
Cohesion: 0.7
Nodes (4): Blob(), CheatBlockPopup(), OrganicBlobsOverlay(), android/app/src/main/java/com/sortyd/app/ui/components/CheatBlockPopup.kt

### Community 55 - "Android theme palette"
Cohesion: 0.7
Nodes (4): android/app/src/main/java/com/sortyd/app/ui/theme/Theme.kt, SortydColors, SortydExtendedColors, SortydTheme()

### Community 56 - "Android typography"
Cohesion: 0.7
Nodes (4): android/app/src/main/java/com/sortyd/app/ui/theme/Type.kt, AppFont, glow(), sortydTypography()

### Community 57 - "Android compact widget"
Cohesion: 0.7
Nodes (3): android/app/src/main/java/com/sortyd/app/widget/SortydWidget.kt, SmallWidgetContent(), SortydWidget

### Community 58 - "Android navigation"
Cohesion: 0.7
Nodes (4): android/app/src/main/java/com/sortyd/app/navigation/SortydNavigation.kt, BottomNavItem, SortydBottomBar(), SortydNavHost()

### Community 59 - "Reminder delivery"
Cohesion: 0.7
Nodes (2): android/app/src/main/java/com/sortyd/app/services/ReminderReceiver.kt, ReminderReceiver

### Community 60 - "Website crawler directives"
Cohesion: 0.7
Nodes (5): Protected website routes, Search indexing, Website sitemap, User-agent: *, website/robots.txt

### Community 61 - "Website language switching"
Cohesion: 1.0
Nodes (3): website/i18n.js, detectLang(), switchLang()

### Community 62 - "Java HMAC verification"
Cohesion: 0.83
Nodes (2): android/TestHmac2.java, TestHmac2

### Community 63 - "Java signing verification"
Cohesion: 0.83
Nodes (2): android/TestHmac.java, TestHmac

### Community 64 - "Android launch screen"
Cohesion: 0.83
Nodes (2): android/app/src/main/java/com/sortyd/app/LaunchActivity.kt, LaunchActivity

### Community 65 - "Daily transition overlay"
Cohesion: 0.83
Nodes (3): android/app/src/main/java/com/sortyd/app/ui/overlays/GhostDayOverlay.kt, AnimatedBlobs(), GhostDayOverlay()

### Community 66 - "Reminder rescheduling"
Cohesion: 0.83
Nodes (2): android/app/src/main/java/com/sortyd/app/services/ReminderRescheduleReceiver.kt, ReminderRescheduleReceiver

### Community 67 - "Kotlin HMAC verification"
Cohesion: 1.0
Nodes (2): android/test_hmac.kt, main()

### Community 68 - "Preview fixtures"
Cohesion: 1.0
Nodes (2): android/app/src/main/java/com/sortyd/app/ui/PreviewMocks.kt, PreviewMocks

### Community 69 - "Day detail sheet"
Cohesion: 1.0
Nodes (2): DayDetailSheet(), android/app/src/main/java/com/sortyd/app/ui/sheets/DayDetailSheet.kt

### Community 70 - "Widget broadcasts"
Cohesion: 1.0
Nodes (2): android/app/src/main/java/com/sortyd/app/widget/SortydWidgetReceiver.kt, SortydWidgetReceiver

### Community 71 - "App Store submission proof"
Cohesion: 0.67
Nodes (2): App Store submission evidence, docs/evidence/2026-11-05/app-store-1.7.7-submitted.jpg

### Community 72 - "Watch bridging header"
Cohesion: 1.0
Nodes (1): ios/SortydWatch Watch App/SortydWatch Watch App-Bridging-Header.h

### Community 73 - "Android root build"
Cohesion: 1.0
Nodes (1): android/build.gradle.kts

### Community 74 - "Android shape tokens"
Cohesion: 1.0
Nodes (1): android/app/src/main/java/com/sortyd/app/ui/theme/Shape.kt

### Community 75 - "Android color tokens"
Cohesion: 1.0
Nodes (1): android/app/src/main/java/com/sortyd/app/ui/theme/Color.kt

### Community 76 - "Android project settings"
Cohesion: 1.0
Nodes (1): android/settings.gradle.kts

### Community 77 - "Android application build"
Cohesion: 1.0
Nodes (1): android/app/build.gradle.kts

### Community 78 - "Android shared components"
Cohesion: 1.0
Nodes (1): android/app/src/main/java/com/sortyd/app/ui/components/Components.kt

## Knowledge Gaps
- **108 isolated node(s):** `ios/SortydWatch Watch App/SortydWatch Watch App-Bridging-Header.h`, `scratch/generate_foreground_svg.py`, `scratch/generate_padded_svg.py`, `scratch/update_translations_v2.py`, `scratch/generate_light_svg.py` (+103 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Watch bridging header`** (2 nodes): `ios/SortydWatch Watch App/SortydWatch Watch App-Bridging-Header.h`, `SortydWatch Watch App-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android root build`** (2 nodes): `android/build.gradle.kts`, `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android shape tokens`** (2 nodes): `android/app/src/main/java/com/sortyd/app/ui/theme/Shape.kt`, `Shape.kt`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android color tokens`** (2 nodes): `Color.kt`, `android/app/src/main/java/com/sortyd/app/ui/theme/Color.kt`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android project settings`** (2 nodes): `android/settings.gradle.kts`, `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android application build`** (2 nodes): `build.gradle.kts`, `android/app/build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android shared components`** (2 nodes): `Components.kt`, `android/app/src/main/java/com/sortyd/app/ui/components/Components.kt`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ios/Sortyd/Views/ListManagementView.swift` connect `iOS list and coach views` to `Android list management`, `Daily state and persistence`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `object()` connect `Preferences and AI server` to `Theme and onboarding`, `Daily state and persistence`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **What connects `ios/SortydWatch Watch App/SortydWatch Watch App-Bridging-Header.h`, `scratch/generate_foreground_svg.py`, `scratch/generate_padded_svg.py` to the rest of the system?**
  _108 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Website features and coaching` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `iOS list and coach views` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Brand and launcher assets` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Daily state and persistence` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
## Coverage and accounting

This refresh covers all detected source code, website and project documents, images and audio assets. Generated build directories and graph outputs are excluded to prevent self indexing. Images were visually inspected through contact sheets. SVG assets were inspected as markup. Audio is indexed by file metadata and duration, without speech transcription. Source claims in old website and release documents are attributed to those sources and can disagree with the current implementation. Exact model token usage is unavailable, so zero token fields are placeholders rather than a claim of free semantic extraction.

The full graph was rebuilt from the current corpus because the previous manifest used obsolete paths. Source provenance links connect document concepts and code definitions. External imports are retained as explicit external nodes.

## Unresolved source discrepancies

The public privacy pages still reference Groq and some say crash reporting is absent. The current release uses Cloudflare Workers AI, Firebase Analytics, Firebase Crashlytics and Microsoft Clarity. The Spanish daily reset article describes midnight, while the implementation uses a 4 AM logical day. These content discrepancies were preserved and flagged during this repository update.
