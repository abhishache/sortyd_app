# Sortyd crash fixes and Firebase verification

5 November 2026. This follows the analytics audit and the user's request to check Firebase and fix the reported problems. The fixes were submitted as version 1.7.7, build 1, on 5 November 2026. App Store Connect confirmed Waiting for Review. Distribution depends on Apple approval.

## Implemented repairs

| Finding | Change |
| :--- | :--- |
| Review prompt missing its app model | Environment objects, selected language, direction and appearance now wrap the entire composed root, including the review overlay. Removed an unused environment dependency from the card. |
| Review card stretched across the screen | Decorative gradient is a background rather than a flexible sizing layer. Card has an opaque surface and content driven height, with scrolling when available space is limited. Improved dark appearance button text and secondary action contrast. |
| Array removal crash in generated lists | Draft tasks and their selection, reminders and health metadata use UUID identities. Deleted or replaced rows cannot address another task by an obsolete array offset. Title and reminder callbacks safely ignore removed drafts. Duplicate generation requests are blocked while one is running. |
| Analytics invalid numeric conversion | CompletionPolicy validates finite fractions and bounds percentages. Snapshots sanitize values on initialization, decoding and mutation. Analytics averages, comparisons and AI percentage formatting use safe conversions. Weighted completion is normalized before display. |
| Health permission missing its model | All five existing sheet presentation sites explicitly supply the app model. This hardens dependency propagation; a physical Mac reproduction was not performed. |
| Review shown event recorded before rendering | Exposure is recorded once when the card appears. The existing seven day eligibility and repeat interval remain. |
| Review tap treated as confirmed review | Suppression is recorded after the OS confirms that the App Store link opened. Existing suppression is preserved for previous users. This state is named link opened, not review submitted. Apple does not provide per person review confirmation. |
| Incomplete outcome analytics | Added AI result events for coaching cache, stale cache, success and failure, plus starter list success and failure with duration. Added onboarding completion. Removed user supplied list names from completion and widget events. No task text, health values or prompts are added to new diagnostics. |
| Existing translations ignored by manual language selection | Shared string lookup now selects the matching language resource bundle explicitly. Fixed related health labels, analytics onboarding messages and task completion formatting. |

## Dictionary crash attribution

Further inspection of the complete downloaded crash logs found APMEExperiment, APMESnapshot and APMETaskManager experiment response frames on another thread. All five inspected samples occurred on 29 September UTC. They match the Firebase Analytics incident documented in [Firebase issue 16728](https://github.com/firebase/firebase-ios-sdk/issues/16728).

Google reports that the triggering incident was corrected on its servers. Firebase 13 also hardens configuration parsing against missing keys. The project now resolves Firebase 13.1.1 and GoogleAppMeasurement 13.0.1, replacing Firebase 12.13.0. [Official release notes](https://firebase.google.com/support/release-notes/ios). The stack and timing provide much stronger attribution than the initial exception only inspection. This is separate from the current review card crash.

## Firebase now works

The existing project sortyd-d067f is accessible through the owner's signed in account. It remains on the free Spark plan. No billing plan or account permissions were changed. No replacement project was created.

Google Analytics includes website activity. After applying a temporary iOS platform filter, the rolling activity card showed approximately 275 users over 30 days, 72 over seven days and about 20 to 21 over one day in the captured report ending 4 November. The unfiltered property showed 367 over 30 days. These are analytics identities, not verified individual people or current installations. Apple first time downloads remain the separate acquisition measure of 1,076 through 3 November. Apple's 101 active devices was an analytics sharing sample rather than the broader SDK audience.

For the selected 28 day period, the iOS report displayed average online active user engagement of 6 minutes 35 seconds and average online session engagement of 1 minute 15 seconds. The former is an aggregate metric over the selected period, not proof of that much daily use. Snapshot values can change with late data. The app only dashboard was left available in the browser.

## Crash reporting setup and evidence

The project now links Firebase Crashlytics. A final archive build phase processes and uploads release symbols. Firebase detected the simulator test app, received intentional debug test crashes and displayed a decoded issue pointing to SortydApp.swift:40 in the debug binary. The corresponding source line is the explicit diagnostic test, not a new accidental crash. Symbols for both the main executable and debug library were uploaded successfully. The per event detail screen had not yet populated at the last check, despite the dashboard listing the decoded test issue.

Two initial test crashes from an earlier temporary binary were received before its symbols were retained. Firebase still showed those as unprocessed. They are QA artifacts, not evidence of new production failures. They were not deleted. The later test uses the uploaded symbols and is visible as a decoded issue.

The diagnostic crash and forced review or language entry points are compiled only under DEBUG. They are excluded from the release archive. The app remains dependent on shipping this new SDK integration before existing users can report through Crashlytics. Historical Apple crash reports are not imported automatically.

## Verification

| Check | Result |
| :--- | :--- |
| iOS release build with Firebase 13.1.1 and Crashlytics | Passed |
| Simulator build, locally signed | Passed |
| Unsigned release archive including symbol upload phase | Passed |
| Completion model, invalid fractions, stale row actions and review scheduling regression suite | Passed |
| Compiled resource bundle checks for Arabic, Spanish and Chinese | Passed |
| Existing history and daylight saving regression checks | 16 passed |
| Existing reminder and Watch conflict regression checks | 18 passed |
| Existing calendar day label checks | 1,681 passed |
| Actual app root forced review prompt on iOS 18 simulator | Rendered without the former environment crash |
| Arabic, Spanish and Chinese review card screenshots | Visually checked after localization repair |
| English light and dark appearance | Visually checked |
| Firebase detects SDK and receives diagnostic crash | Confirmed in console |
| Latest diagnostic issue decoded to app source line | Confirmed in console |

Run the new regression suite with `bash tests/run_crash_regressions.sh`. Optionally pass a built Sortyd.app directory to include compiled translation checks.

Build evidence: /private/tmp/sortyd-verified-build.log, /private/tmp/sortyd-simulator-signed-build.log, /private/tmp/sortyd-final-archive.log. Test archive: /private/tmp/Sortyd-verified-fixes.xcarchive. The archive is unsigned and is not an App Store upload.

Screenshots: [English dark appearance](evidence/2026-11-05/review-en-dark.png), [Arabic](evidence/2026-11-05/review-ar.png), [Spanish](evidence/2026-11-05/review-es.png), [Chinese](evidence/2026-11-05/review-zh.png). The translated screenshots precede the final secondary button contrast adjustment.

## Remaining verification limits

No physical iPhone, iOS 26 or 27 device, Mac health permission flow, full button interaction sweep, large Dynamic Type setting or landscape matrix was tested. New AI outcome events compile but their delivery through actual coaching and list generation requests has not been exercised in this session. This work does not establish current AI backend availability or fix every possible app defect.

Existing users still need a signed update. Production crash rate and retention recovery can only be measured after that update is distributed. Review suppression confirms a successful link open only. It cannot determine whether a person actually submitted an App Store review.

## Layout review

| Severity | Location | Before | After | Why |
| :--- | :--- | :--- | :--- | :--- |
| HIGH | ios/Sortyd/Views/ReviewPromptView.swift | Flexible gradient stretched header and allowed background content to compete with the prompt | Opaque card, natural header height and bounded scrolling | Keeps content grouped and actions accessible when text grows |
| MEDIUM | ios/Sortyd/ViewModels/AppViewModel.swift | Selected Arabic mirrored the layout while strings stayed English | Explicit localized resource bundle selection | Preserves reading order and comprehensible controls |

Approve for the inspected portrait simulator layouts. Physical devices, landscape and large Dynamic Type remain not verified.


## Release 1.7.7 verification

The signed archive and App Store Connect upload succeeded. Version 1.7.7, build 1, was attached and submitted through Chrome. Apple displayed Waiting for Review and 1 Item Submitted. The required age questionnaire was completed with the calculated 9+ rating preserved. Release notes were saved in English (U.K.), Arabic, Spanish (Mexico) and Simplified Chinese. Device ID, Crash Data, Performance Data and Other Diagnostic Data disclosures were published for analytics and app functionality without advertising tracking.

Live synthetic requests exercised the actual AICoach implementation against the production Cloudflare endpoint in English, Arabic, Spanish and Simplified Chinese. Starter lists and complete coaching responses decoded in all four languages. Final measured starter requests took 0.89 to 1.05 seconds and coaching took 1.53 to 2.70 seconds. Repeat daily coaching reads used the cache immediately. These checks establish response contracts and caching. They do not certify every generated statement as accurate. Some multilingual phrasing remained weak in inspected samples.

The server now requests and validates explicit JSON schemas. Batch results are wrapped for inference and unwrapped into the array contract expected by existing app versions. Invalid response shapes return a controlled error. Null request bodies are rejected and output token limits are bounded. The existing Cloudflare model and free plan were retained.

The app now separates coaching caches by language, coalesces duplicate concurrent requests, retries incomplete daily analyses and derives the analysis window from available history. Removed unrelated fitness examples from starter prompts. All 1,710 non-English catalog translations and formatting contracts passed checks. Regression tests passed for coach caching, worker contracts, completion safety, stale rows, seven day review timing, 16 history checks, 18 reminder checks and 1,681 calendar label checks.

Apple reported missing vendor dSYMs for FirebaseAnalytics, GoogleAppMeasurement, GoogleAppMeasurementIdentitySupport and GoogleAdsOnDeviceConversion. The app, widget, Watch and Clarity dSYMs are present in the archive. A separate manual Crashlytics release symbol upload was blocked when automatic approval review hit its usage limit. Production symbol processing still needs verification after release. The previously received simulator test crash confirms SDK ingestion, not release symbol completion.

Submission evidence is saved at [App Store confirmation](evidence/2026-11-05/app-store-1.7.7-submitted.jpg).

The graph refresh also identified stale privacy policy copy in the website's language variants referring to Groq and, in some variants, absence of crash reporting. This is an unresolved public documentation mismatch with the current Cloudflare and Crashlytics integration and requires a separate content correction.
