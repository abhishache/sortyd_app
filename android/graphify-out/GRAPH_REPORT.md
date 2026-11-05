# Graph Report - .  (2026-05-04)

## Corpus Check
- Corpus is ~42,797 words - fits in a single context window. You may not need a graph.

## Summary
- 460 nodes · 678 edges · 28 communities detected
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 116 edges (avg confidence: 0.8)
- Token cost: 1,200 input · 800 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Core Business Logic|Core Business Logic]]
- [[_COMMUNITY_UI Task Management|UI Task Management]]
- [[_COMMUNITY_Health Task Detection|Health Task Detection]]
- [[_COMMUNITY_Data Models & Repository|Data Models & Repository]]
- [[_COMMUNITY_Health Connect & Onboarding Integration|Health Connect & Onboarding Integration]]
- [[_COMMUNITY_Core UI Components|Core UI Components]]
- [[_COMMUNITY_Database Access|Database Access]]
- [[_COMMUNITY_Widget Implementation|Widget Implementation]]
- [[_COMMUNITY_Activity Lifecycle & Intents|Activity Lifecycle & Intents]]
- [[_COMMUNITY_Completion Calculation Tests|Completion Calculation Tests]]
- [[_COMMUNITY_Analytics & DNA UI|Analytics & DNA UI]]
- [[_COMMUNITY_Widget Drawing Utilities|Widget Drawing Utilities]]
- [[_COMMUNITY_Streak Calculation Logic|Streak Calculation Logic]]
- [[_COMMUNITY_User Preferences & Settings|User Preferences & Settings]]
- [[_COMMUNITY_AI Coach & Security|AI Coach & Security]]
- [[_COMMUNITY_Widget Interactivity|Widget Interactivity]]
- [[_COMMUNITY_Reminders & Notifications|Reminders & Notifications]]
- [[_COMMUNITY_Application Initialization|Application Initialization]]
- [[_COMMUNITY_Database Configuration|Database Configuration]]
- [[_COMMUNITY_HMAC Java Test 2|HMAC Java Test 2]]
- [[_COMMUNITY_HMAC Java Test 1|HMAC Java Test 1]]
- [[_COMMUNITY_Reminder Broadcast Receiver|Reminder Broadcast Receiver]]
- [[_COMMUNITY_App Review Management|App Review Management]]
- [[_COMMUNITY_Lifecycle & Reset Semantic Flow|Lifecycle & Reset Semantic Flow]]
- [[_COMMUNITY_Widget Receiver|Widget Receiver]]
- [[_COMMUNITY_List & Nav Semantic Flow|List & Nav Semantic Flow]]
- [[_COMMUNITY_Health & Onboarding Semantic Flow|Health & Onboarding Semantic Flow]]
- [[_COMMUNITY_Design Parity Semantic Flow|Design Parity Semantic Flow]]

## God Nodes (most connected - your core abstractions)
1. `HealthTaskTypeTest` - 41 edges
2. `SortydViewModel` - 39 edges
3. `SortydDao` - 30 edges
4. `SortydRepository` - 26 edges
5. `TaskListTest` - 25 edges
6. `HomeScreen()` - 16 edges
7. `WidgetUtils` - 15 edges
8. `StreakCalculationTest` - 14 edges
9. `UserPreferences` - 14 edges
10. `DailySnapshot` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Android/iOS Widget Parity` --requires--> `Glassy UI Effects`  [INFERRED]
  build_log.txt → app/src/main/java/com/sortyd/app/widget/SortydWidget.kt
- `HomeScreen()` --calls--> `MonthPickerSheet()`  [INFERRED]
  app/src/main/java/com/sortyd/app/ui/screens/home/HomeScreen.kt → app/src/main/java/com/sortyd/app/ui/components/HeatmapCalendar.kt
- `HomeScreen()` --calls--> `ThemeToggle()`  [INFERRED]
  app/src/main/java/com/sortyd/app/ui/screens/home/HomeScreen.kt → app/src/main/java/com/sortyd/app/ui/components/Components.kt
- `SortydNavHost()` --calls--> `HomeScreen()`  [INFERRED]
  app/src/main/java/com/sortyd/app/navigation/SortydNavigation.kt → app/src/main/java/com/sortyd/app/ui/screens/home/HomeScreen.kt
- `SortydNavHost()` --calls--> `ListsScreen()`  [INFERRED]
  app/src/main/java/com/sortyd/app/navigation/SortydNavigation.kt → app/src/main/java/com/sortyd/app/ui/screens/lists/ListsScreen.kt

## Communities (36 total, 17 thin omitted)

### Community 0 - "Core Business Logic"
Cohesion: 0.06
Nodes (4): CoachRecap, Pillar, ReminderConflictInfo, SortydViewModel

### Community 1 - "UI Task Management"
Cohesion: 0.1
Nodes (14): TaskListTest, AIStarterListScreen(), DraftTask, GeneratedListContent(), MarqueeChipRow(), TypingPlaceholder(), AddListBottomSheet(), ListCardItem() (+6 more)

### Community 3 - "Data Models & Repository"
Cohesion: 0.07
Nodes (9): SortydTask, TaskEntity, toDomain(), toEntity(), TaskListEntity, TaskListWithTasks, toDomain(), getInstance() (+1 more)

### Community 4 - "Health Connect & Onboarding Integration"
Cohesion: 0.08
Nodes (23): AddTask, AppLanguage, DeleteTask, EditTask, HealthSnapshot, HealthTaskType, ReorderTasks, ToggleTask (+15 more)

### Community 5 - "Core UI Components"
Cohesion: 0.11
Nodes (26): Blob(), CheatBlockPopup(), OrganicBlobsOverlay(), DonutChart(), dualGlow(), EmptyState(), FingerTapOverlay(), SectionLabel() (+18 more)

### Community 7 - "Widget Implementation"
Cohesion: 0.09
Nodes (17): WidgetData, WidgetTask, HeatmapWidgetContent(), SortydHeatmapWidget, SortydHeatmapWidgetReceiver, HealthDialItem(), LargeWidgetContent(), SortydLargeWidget (+9 more)

### Community 8 - "Activity Lifecycle & Intents"
Cohesion: 0.1
Nodes (16): MainActivity, CoachScreen(), OverallInsightBanner(), PillarCard(), ProcrastinationSection(), SkeletonCard(), SummaryChip(), WeeklyGradeBanner() (+8 more)

### Community 9 - "Completion Calculation Tests"
Cohesion: 0.2
Nodes (5): SnapshotTest, DailySnapshot, SnapshotEntity, toDomain(), toEntity()

### Community 10 - "Analytics & DNA UI"
Cohesion: 0.23
Nodes (15): AnalyticsPeriod, AnalyticsScreen(), BannerBlock(), DNABar(), DNASection(), HeroBlock(), InsightChip(), InsightSection() (+7 more)

### Community 14 - "AI Coach & Security"
Cohesion: 0.29
Nodes (5): AICoach, AnalysisPillar, AnalysisResult, ParsedTask, StarterList

### Community 23 - "Lifecycle & Reset Semantic Flow"
Cohesion: 1.0
Nodes (3): Quick Add Deep-link, MainActivity Lifecycle, 4 AM Reset Logic

## Knowledge Gaps
- **29 isolated node(s):** `AnalyticsPeriod`, `SortydExtendedColors`, `SortydColors`, `AppFont`, `SortydWidgetReceiver` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `DailySnapshot` connect `Completion Calculation Tests` to `Core Business Logic`, `Streak Calculation Logic`?**
  _High betweenness centrality (0.125) - this node is a cross-community bridge._
- **Why does `TaskList` connect `UI Task Management` to `Data Models & Repository`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **What connects `AnalyticsPeriod`, `SortydExtendedColors`, `SortydColors` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Core Business Logic` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `UI Task Management` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `Health Task Detection` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Data Models & Repository` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._