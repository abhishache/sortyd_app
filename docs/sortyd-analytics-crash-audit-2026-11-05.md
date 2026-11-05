# Sortyd analytics and crash audit

Audit date: 5 November 2026. App Store Connect app 6762193535, bundle com.sortyd.sortyd. Apple metrics available through 3 November; inspected Xcode crash samples extend through 4 November. These are Apple platform results, not a combined iOS and Android user count.

Followup: Firebase access was restored after this audit. Implementation and verification results are recorded in [the fix report](sortyd-crash-fixes-2026-11-05.md). The findings below describe the original state before repairs. The dictionary crash attribution and broader active user counts have since been clarified.

## Verdict

There is a confirmed production crash in the review prompt. Multiple differently named SwiftUI crash groups resolve to `ReviewPromptCard.vm.getter`, where the required environment object is missing. Samples include the current 1.7.6 release. This is an app defect requiring a corrected build, not an AI server outage.

There are two other confirmed historical crash paths whose unsafe operations remain in the current source: deleting an AI generated task with an invalid array index, and converting a nonfinite analytics value to an integer. A separate dictionary exception remains unattributed. An older Mac health permission crash also needs regression coverage.

Store conversion is relatively strong. Stability, retention, measurement access and declining acquisition are the immediate business concerns. This audit did not change application code or deploy a build. Stack trace and source analysis establish the findings; a repaired build has not been tested.

## Verified audience and activity

| Metric | Value | Period and meaning |
| :--- | ---: | :--- |
| First time downloads | 1,076 | Lifetime, 18 April to 3 November |
| Total downloads | 1,131 | Lifetime; includes redownloads |
| Redownloads | 55 | Derived as total downloads minus first time downloads |
| Observed monthly active devices | 101 | 5 October to 3 November; Apple analytics sharing sample |
| Observed daily active devices | 7 | 3 November; same sampling limitation |
| Sessions | 810 | 5 October to 3 November; same sampling limitation |
| New first time downloads | 163 | 5 October to 3 November |
| Crash events | 33 | 5 October to 3 November; 32 on 1.7.6, one on 1.7.3 |
| Crash events per 100 sessions | 4.07 | Derived from 33 / 810 × 100 |
| Lifetime crash events | 164 | Apple recorded events across versions |
| Lifetime deletions | 244 | Sampled deletion events, not unique former users |

The clearest answer to “how many have downloaded?” is **1,076 first time downloads**, plus 55 redownloads. It is not an exact count of individual humans or of devices that still have Sortyd installed.

The clearest verified recent audience measure is **101 observed active devices over 30 days**. It excludes people who do not share usage analytics with developers. Seven devices were active on the most recent reported day. Neither figure is a live concurrent user count. The actual total active population remains unverified.

Do not subtract the 244 deletions from 1,076 downloads to estimate the installed base. These measures have different populations and event semantics. Do not describe 33 crashes as 33 affected people or calculate crash free users as 100 minus 4.07. Repeated crashes can affect the same device or session.

The 810 sessions correspond to roughly eight sessions per observed monthly active device. This does not establish session duration or confirm the previously discussed 10 to 15 minutes per day.

[Apple metric definitions](https://developer.apple.com/help/app-store-connect-analytics/reference/metrics-definitions/) explain downloads, sampled usage, active devices, sessions and deletions.

## Acquisition trend

| Month | First time downloads |
| :--- | ---: |
| April, from 18 April | 123 |
| May | 52 |
| June | 26 |
| July | 99 |
| August | 310 |
| September | 276 |
| October | 179 |
| November, first three days | 11 |

Recent comparable periods show 163 first time downloads from 5 October to 3 November versus 245 from 5 September to 4 October, a decline of 33.5%. The latest seven days had 26 versus 22 in the preceding seven days, so the shorter trend is better. Three days of November should not be compared directly with full months.

| Source | First time downloads, recent 30 days | Share |
| :--- | ---: | ---: |
| App Store search | 64 | 39.3% |
| Web referrers | 48 | 29.4% |
| App referrers | 43 | 26.4% |
| App Store browse | 8 | 4.9% |

This indicates limited organic browse discovery and meaningful reliance on referrals. Search terms, campaign attribution and territory cohorts need further analysis before choosing a marketing channel. Strong conversion alone does not prove broad product demand.

## Market comparison from the app's own Apple benchmark dashboard

Peer group: free Health & Fitness apps, all app sizes. Latest benchmark week inspected: 12 to 18 October. These are weekly cohorts, not the same population or period as the recent 30 day totals.

| Measure | Sortyd | Peer reference displayed | Interpretation |
| :--- | ---: | :--- | :--- |
| Download conversion | 33.94% | 75th percentile about 16.27% | Above the 75th percentile; a relative strength |
| Crash rate | 4.50% | 75th percentile about 0.11% | Much worse; lower is better |
| Day 1 retention | 15.28% | Median about 27.26%; 25th percentile 18.77% | Below the 25th percentile |
| Day 7 retention | 9.72% | Median about 10.51% | Between the 25th and 50th percentiles |
| Day 28 retention | Unavailable | Dashboard did not provide a usable result | No conclusion possible |

The previous benchmark week, 5 to 11 October, showed conversion 27.91%, crash rate 5.85% and Day 1 retention 29%. This variation is a reason to inspect several cohorts rather than claim that one week defines the product.

Apple adds privacy noise to peer values and uses analytics sharing data for usage comparisons. Treat the values as directional. The peer category is broader than habit trackers. [Apple benchmark methodology and definitions](https://developer.apple.com/help/app-store-connect-analytics/benchmarks/peer-group-benchmarks).

The evidence supports prioritising reliable use and early repeat engagement over another visual redesign or aggressive review requests. It does not prove that crashes caused every lost user. That requires cohort and event data linked to crash exposure.

## Crash findings

### 1. Review prompt missing its environment object

Priority: immediate. Confidence: confirmed by symbolicated production stacks and matching source.

The current root is `ios/Sortyd/SortydApp.swift`. At lines 25 and 26, the environment objects are attached to `ContentView`. The review overlay is added later at line 73. `ReviewPromptCard` is instantiated at line 80 without supplying its required objects to that overlay branch.

`ios/Sortyd/Views/ReviewPromptView.swift:8` declares `@EnvironmentObject var vm: AppViewModel`. The header reads `vm.localized(...)` at line 55. Crash samples terminate in `EnvironmentObject.error()` followed by `ReviewPromptCard.vm.getter` and the header builder. Samples cover releases 1.7.3, 1.7.4 and 1.7.6. The latest samples extend into November.

Eight of the twelve Organizer groups inspected have samples tracing back to this same review card. Some group names mention layout, AttributeGraph or view body updates rather than the card. They should not be counted as eight unrelated root causes.

The card becomes eligible after the stored age reaches seven days and can recur after seven days following a qualifying task completion. It can therefore interrupt an engaged user immediately after a positive action. The stored install date is created on first access, not necessarily on the actual installation date.

Recommended repair: provide the environment objects outside the complete composed root, or explicitly inject them into the card. Audit language and layout direction inheritance as part of the same repair. Consider passing only the dependencies the card actually needs. The unused theme environment declaration should not be retained without purpose.

The preview injects both objects, which conceals the production composition defect. Verification must launch the actual application root, make the review prompt eligible and complete a task. Include fresh and upgraded data, supported languages and RTL, light and dark appearance, dismissal and opening the App Store. Passing compilation and App Review did not validate this path.

### 2. AI generated task deletion uses an unstable array index

Priority: high. Confidence: historical production crash confirmed; unsafe operation remains in current source.

The 1.4 sample reports `Swift runtime failure: Index out of range` in `StarterListSheet.removeTask(at:)`. The current implementation at `ios/Sortyd/Views/AITaskEntryView.swift:1076` still calls `editableTasks.remove(at: idx)` without checking that the index remains valid. Rows iterate array indices at line 778 and use indexed bindings and actions.

Recommended repair: use stable task identities for row state, bindings, selection, reminder and health metadata. Resolve the current item at action time and safely ignore obsolete actions. A bounds check prevents one trap but does not fix the possibility that a shifted index refers to a different task.

Verification should include rapid deletion, deleting adjacent and final rows during animation, editing while deleting and an AI result replacing the collection. Check that reminder and health metadata remain attached to the intended task.

### 3. Analytics converts an invalid floating point value to Int

Priority: high. Confidence: historical production crash confirmed; conversion remains unguarded.

A 1.7.5 sample reports `Double value cannot be converted to Int because it is either infinite or NaN` in `AnalyticsView.avg.getter`. The current source at `ios/Sortyd/Views/AnalyticsView.swift:126` guards an empty collection but directly converts the computed result to `Int` at line 128. This does not protect against nonfinite values.

The historical sample does not establish where the invalid value originated. Do not assume it was merely division by an empty array. The current code already guards that case. Snapshot values and other percentage conversions also lack a shared finite value boundary, including `Models/Models.swift:215` and the period comparison in `AnalyticsView.swift:180`.

Recommended repair: validate fractions when computing and accepting snapshots, enforce the intended range, and use safe conversion for displayed percentages. Decide explicitly how invalid history is repaired without deleting otherwise valid user data. Include NaN, infinity, extreme values, empty history and upgraded data in regression tests.

### 4. Dictionary exception in 1.7.6

Priority: high investigation. Confidence: exception confirmed; owner unresolved.

Organizer shows a separate group affecting eight devices over its selected history. The inspected 1.7.6 samples report `-[__NSDictionaryM setObject:forKeyedSubscript:]: key cannot be nil`. The exception occurs on a background thread. Available exception stacks show Foundation and dispatch frames without a trustworthy app or SDK owner.

It would be incorrect to label this a Clarity or Firebase defect on that evidence. Retain complete diagnostic logs and matching symbols. Add privacy safe breadcrumbs around relevant lifecycle and SDK operations, and isolate SDK combinations in a nonproduction test build. Reproduce before selecting a repair.

### 5. Historical health permission dependency crash on Mac

Priority: medium investigation and regression coverage. Confidence: historical stack confirmed; current reproduction unverified.

A separate 1.4 Mac sample ends in `EnvironmentObject.error()` followed by `HealthPermissionSheet.vm.getter`. The sheet still declares an environment dependency in `ios/Sortyd/Views/HealthTaskViews.swift:332`. Current presentation sites include HomeView, AITaskEntryView and ListManagementView.

A sheet can inherit environment correctly from its presenter, so the absence of an explicit injection at every call site is not itself proof that each current flow is broken. Reproduce each supported presentation route, particularly nested sheets and the iPhone app running on Mac if distributed there. Make dependency propagation explicit where the root is incomplete.

### Organizer groups inspected

Counts are devices displayed per group in the selected history, not mutually exclusive users. Do not sum this column into a unique affected user total.

| Displayed group signature | Devices | Inspected sample path |
| :--- | ---: | :--- |
| ViewBodyAccessor update, +44 | 35 | ReviewPromptCard |
| EnvironmentObject error | 21 | ReviewPromptCard |
| ViewBodyAccessor update, +48 | 11 | ReviewPromptCard |
| CoreFoundation exception preprocessing | 8 | Dictionary nil key, owner unresolved |
| Attribute or BodyAccessor group | 8 | ReviewPromptCard |
| Attribute initialization | 6 | ReviewPromptCard |
| Array.remove | 3 | StarterListSheet deletion |
| LayoutComputer sizeThatFits | 2 | ReviewPromptCard |
| AnyRuleContext subscript | 2 | ReviewPromptCard |
| UnaryLayoutComputer update | 2 | ReviewPromptCard |
| AnalyticsView.avg | 1 | Nonfinite Double to Int |
| EnvironmentObject error, Mac | 1 | HealthPermissionSheet |

## Why analytics does not answer the user count question clearly

Apple separates downloads from usage. Its default date range was a recent period rather than lifetime. Switching metrics can also change whether a headline represents a period total or daily average. This explains why isolated dashboard numbers appeared inconsistent.

Firebase was initially signed into the Courtside account in Chrome. In the in app browser, the Sortyd account is available, but Firebase redirects to an MFA screen and also displays a project or permission error. Direct Google Analytics opens its initial setup screen rather than a property report. These screens do not prove the Firebase project was deleted or that no app events have ever been collected. They do prevent verification of broader active user counts here.

The current Xcode project links Firebase Analytics and Clarity. It does not link Firebase Crashlytics or contain a Crashlytics upload phase. Analytics and session recording do not establish that native crash reporting is configured. Recommended setup includes the Crashlytics SDK, correct symbols and a verified test crash from a test build. [Official Firebase setup](https://firebase.google.com/docs/crashlytics/ios/get-started).

Current custom events leave important gaps. `ai_coach_used` is logged before the request finishes, while a cache hit returns without that event. It cannot reliably mean a user received coaching. Review prompt shown is logged before rendering completes, so it can be followed by the card crashing. Review tapped is not a submitted review. The inspected instrumentation lacks a complete onboarding completion and AI outcome funnel.

Recommended dashboard: first opens, daily and monthly active app instances, returning users, onboarding completion, first list, first task completion, AI request and result with latency and cache status, reminders opened, crash free users and sessions, and review card exposure and App Store link taps. Show platform, app version, date range and data delay beside every headline. Avoid user task text, health details and list names in analytics parameters. Device or app instance IDs still do not uniquely identify humans.

## Review measurement defect

`ios/Sortyd/ViewModels/AppViewModel.swift:1033` records `hasReviewed = true` before opening the App Store URL. It does not verify that the URL opened or that a review was submitted. Users can tap and return without reviewing yet be suppressed permanently.

Name this state accurately, such as review link opened or review request completed. Apple does not expose a reliable per user signal that confirms a submitted App Store review. A nonintrusive suppression policy can respect the user's request without claiming to detect actual reviewers. Repair the crash before making the prompt more frequent.

## Product gaps relative to established habit apps

The strongest measured gap is reliability. The second is early retention, although small cohorts fluctuate. The next gap is the ability to explain what users actually complete or abandon because outcome tracking is incomplete.

There is also a resilience gap worth validating before adding more features. The inspected iOS persistence is local app group storage. No CloudKit sync or user accessible data backup and restore flow was found in the audited paths. Shared widget storage does not itself provide cross device recovery. Streaks documents iCloud sync, automatic backup, import and export. Habitify advertises cross device sync, flexible schedules, and skip, miss and pause states. These are examples of established expectations, not evidence that copying every feature will improve Sortyd's retention.

[Streaks support and recovery features](https://streaks.app/support/). [Habitify's developer supplied App Store feature description](https://apps.apple.com/us/app/habitify-habit-tracker/id1111447047). [Strides help and habit state handling](https://www.stridesapp.com/help/).

Prioritise dependable daily completion, correct calendar and reminder behaviour, recoverable progress and a clear first success. The historical notification, calendar and AI complaints remain important regression scenarios, but this analytics audit did not retest their entire implementations or establish their current server status.

## Recommended execution order

| Order | Work | Evidence required before declaring completion |
| :--- | :--- | :--- |
| 1 | Repair review card dependency scope | Eligible prompt works through the actual application root without a crash |
| 2 | Repair task identity and numeric boundaries | Targeted regressions reproduce the former failure and pass after repair |
| 3 | Investigate dictionary and Mac sheet exceptions | Reproduction or attributable diagnostic evidence; no guessed SDK blame |
| 4 | Restore Firebase access and configure crash reporting | Property visible, test events received, symbolicated test crash received |
| 5 | Correct review semantics and AI outcome events | Dashboard distinguishes attempts, cached results, failures and actual UI exposure |
| 6 | Ship a verified stability update | Release configuration tested, upgrade data preserved, symbols retained |
| 7 | Measure recovery before increasing promotion | Version specific crash trend and comparable Day 1 and Day 7 cohorts improve |

An initial operational goal could be a crash event rate below 0.1%, zero occurrences of the known repaired signatures and Day 1 retention above the displayed peer median over several cohorts. These are proposed goals, not promised outcomes or universal market standards. Small samples need longer observation.

## Evidence and limits

Sources inspected: authenticated App Store Connect Metrics and Benchmarks in Chrome; Xcode Organizer's twelve listed crash groups and locally downloaded diagnostic samples; current iOS source and project configuration; Firebase and Google Analytics access screens in the in app browser; primary vendor documentation linked above. Existing Graphify output helped locate relevant project components; conclusions were checked against source.

Authenticated analytics entry: https://appstoreconnect.apple.com/apps/6762193535/analytics/metrics

Authenticated peer comparisons: https://appstoreconnect.apple.com/apps/6762193535/analytics/benchmarks

No exact all platform installed base, total active human count, real time concurrent count, revenue estimate, session duration, actual per user review status or current AI backend success rate was established. Firebase access and suitable instrumentation are needed to close those gaps. No production state or application code was changed by this audit.
