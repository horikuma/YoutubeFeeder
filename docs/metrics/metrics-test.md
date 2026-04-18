## 2026/04/18

### Summary
- logic tests: 131 cases / 5.681s
- ui tests: 2 cases / 8.324s
- logic areas:
  - App: 4 cases / 0.003s
  - Browse: 21 cases / 0.012s
  - Formatting: 6 cases / 0.009s
  - Home: 9 cases / 0.009s
  - Layout: 10 cases / 0.008s
  - Ordering: 5 cases / 0.002s
  - Parsing: 28 cases / 0.039s
  - Policies: 16 cases / 0.011s
  - Storage: 32 cases / 5.588s
- ui areas:
  - Home: 2 cases / 8.324s

### Logic Tests
- ID: `AppLaunchModeTests.testAllowsBackgroundRefreshOnlyInNormalMode`
- 概要: Allows Background Refresh Only In Normal Mode
- 分類: `logic` / `App`
- ファイル: `YoutubeFeederTests/Unit/App/AppLaunchModeTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.000s`

- ID: `AppLaunchModeTests.testAutoRefreshOnLaunchCanBeEnabledInUITestMode`
- 概要: Auto Refresh On Launch Can Be Enabled In UI Test Mode
- 分類: `logic` / `App`
- ファイル: `YoutubeFeederTests/Unit/App/AppLaunchModeTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `AppLaunchModeTests.testAutoRefreshOnLaunchDefaultsToEnabledInNormalMode`
- 概要: Auto Refresh On Launch Defaults To Enabled In Normal Mode
- 分類: `logic` / `App`
- ファイル: `YoutubeFeederTests/Unit/App/AppLaunchModeTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `AppLaunchModeTests.testAutoRefreshOnLaunchIsDisabledInUITestModeUntilExplicitlyEnabled`
- 概要: Auto Refresh On Launch Is Disabled In UI Test Mode Until Explicitly Enabled
- 分類: `logic` / `App`
- ファイル: `YoutubeFeederTests/Unit/App/AppLaunchModeTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseLogicTests.testApplyDefaultSelectionUsesFirstAvailableChannel`
- 概要: Apply Default Selection Uses First Available Channel
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelBrowseLogicTests.testLoadingLifecycleStoresVideosOnceAndTracksLoadingState`
- 概要: Loading Lifecycle Stores Videos Once And Tracks Loading State
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `ChannelBrowseLogicTests.testRefreshSelectedChannelVideosReplacesSelectedChannelVideos`
- 概要: Refresh Selected Channel Videos Replaces Selected Channel Videos
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseLogicTests.testRemovalFeedbackAndPendingRemovalCanBeManagedIndependently`
- 概要: Removal Feedback And Pending Removal Can Be Managed Independently
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelBrowseLogicTests.testSetItemsClearsSelectionWhenChannelDisappears`
- 概要: Set Items Clears Selection When Channel Disappears
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testBuildHandlesEmptyList`
- 概要: Build Handles Empty List
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelBrowseTipsSummaryTests.testBuildSummarizesChannelCountAndSort`
- 概要: Build Summarizes Channel Count And Sort
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testDesktopInteractionPlatformUsesDesktopHints`
- 概要: Desktop Interaction Platform Uses Desktop Hints
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testRemoteSearchPresentationBeginRefreshShowsRefreshingChip`
- 概要: Remote Search Presentation Begin Refresh Shows Refreshing Chip
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testRemoteSearchPresentationBuildFallsBackToFirstVideoForSplitSelection`
- 概要: Remote Search Presentation Build Falls Back To First Video For Split Selection
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelBrowseTipsSummaryTests.testRemoteSearchPresentationBuildPreservesExistingSplitSelectionWhenChannelStillExists`
- 概要: Remote Search Presentation Build Preserves Existing Split Selection When Channel Still Exists
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `ChannelBrowseTipsSummaryTests.testRemoteSearchPresentationBuildShowsChipWhenFetchedAtExists`
- 概要: Remote Search Presentation Build Shows Chip When Fetched At Exists
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testRemoteSearchPresentationDismissChipAndLoadMore`
- 概要: Remote Search Presentation Dismiss Chip And Load More
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelBrowseTipsSummaryTests.testTouchInteractionPlatformUsesTouchHints`
- 概要: Touch Interaction Platform Uses Touch Hints
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/ChannelBrowseTipsSummaryTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `KeywordSearchLogicTests.testDefaultsStartEmpty`
- 概要: Defaults Start Empty
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/KeywordSearchLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `KeywordSearchLogicTests.testSetResultReplacesCurrentResult`
- 概要: Set Result Replaces Current Result
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/KeywordSearchLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `RemoteSearchLogicTests.testDefaultsStartEmptyAndIdle`
- 概要: Defaults Start Empty And Idle
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/RemoteSearchLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `RemoteSearchLogicTests.testSetResultAndSplitSelectionLifecycle`
- 概要: Set Result And Split Selection Lifecycle
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/RemoteSearchLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `VideoListLogicTests.testAutomaticRefreshLifecycleTracksLoadingStateAndVideos`
- 概要: Automatic Refresh Lifecycle Tracks Loading State And Videos
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/VideoListLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `VideoListLogicTests.testDefaultsStartEmptyAndIdle`
- 概要: Defaults Start Empty And Idle
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/VideoListLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `VideoListLogicTests.testRemovalFeedbackAndPendingRemovalCanBeManagedIndependently`
- 概要: Removal Feedback And Pending Removal Can Be Managed Independently
- 分類: `logic` / `Browse`
- ファイル: `YoutubeFeederTests/Unit/Browse/VideoListLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `AppConsoleLoggerTests.testErrorSummaryIncludesDecodingPathForMissingKey`
- 概要: Error Summary Includes Decoding Path For Missing Key
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppConsoleLoggerTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.004s`

- ID: `AppConsoleLoggerTests.testRenderLineKeepsSingleLineConsoleFormat`
- 概要: Render Line Keeps Single Line Console Format
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppConsoleLoggerTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.000s`

- ID: `AppConsoleLoggerTests.testResponsePreviewCondensesNewlinesAndTruncates`
- 概要: Response Preview Condenses Newlines And Truncates
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppConsoleLoggerTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.001s`

- ID: `AppConsoleLoggerTests.testSanitizedKeywordCollapsesWhitespaceAndTruncates`
- 概要: Sanitized Keyword Collapses Whitespace And Truncates
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppConsoleLoggerTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.000s`

- ID: `AppFormattingTests.testVideoTileBadgeTextHandlesMissingDurationAndViewCount`
- 概要: Video Tile Badge Text Handles Missing Duration And View Count
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppFormattingTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.001s`

- ID: `AppFormattingTests.testVideoTileBadgeTextRoundsDurationToMinutesAndFormatsViewCount`
- 概要: Video Tile Badge Text Rounds Duration To Minutes And Formats View Count
- 分類: `logic` / `Formatting`
- ファイル: `YoutubeFeederTests/Unit/Formatting/AppFormattingTests.swift`
- 開始: `10:45:09`
- 終了: `10:45:09`
- 所要時間: `0.003s`

- ID: `ChannelRegistrationLogicTests.testCSVImportLifecycleHandlesPresentationAndExecution`
- 概要: CSV Import Lifecycle Handles Presentation And Execution
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/ChannelRegistrationLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.004s`

- ID: `ChannelRegistrationLogicTests.testDefaultsStartEmptyAndIdle`
- 概要: Defaults Start Empty And Idle
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/ChannelRegistrationLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRegistrationLogicTests.testRequestCSVImportPresentsImporterWithoutStartingExecution`
- 概要: Request CSV Import Presents Importer Without Starting Execution
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/ChannelRegistrationLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRegistrationLogicTests.testSubmitLifecycleUpdatesOnlyRegistrationState`
- 概要: Submit Lifecycle Updates Only Registration State
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/ChannelRegistrationLogicTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `HomeScreenLogicTests.testDefaultsStartWithDefaultSortAndNoFeedback`
- 概要: Defaults Start With Default Sort And No Feedback
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/HomeScreenLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `HomeScreenLogicTests.testRegistryTransferLifecycleKeepsResetStateClearedAndRecordsOutcome`
- 概要: Registry Transfer Lifecycle Keeps Reset State Cleared And Records Outcome
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/HomeScreenLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `HomeScreenLogicTests.testRequestResetAllSettingsMarksDialogAsPresented`
- 概要: Request Reset All Settings Marks Dialog As Presented
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/HomeScreenLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `HomeScreenLogicTests.testResetLifecycleKeepsTransferStateClearedAndRecordsOutcome`
- 概要: Reset Lifecycle Keeps Transfer State Cleared And Records Outcome
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/HomeScreenLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `HomeScreenLogicTests.testSelectChannelSortDescriptorUpdatesOnlyTheSortState`
- 概要: Select Channel Sort Descriptor Updates Only The Sort State
- 分類: `logic` / `Home`
- ファイル: `YoutubeFeederTests/Unit/Home/HomeScreenLogicTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `AppLayoutTests.testCompactWidthNeverUsesSplitChannelBrowser`
- 概要: Compact Width Never Uses Split Channel Browser
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/AppLayoutTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `AppLayoutTests.testRegularWidthUsesReadableContentWidthForSingleColumnLists`
- 概要: Regular Width Uses Readable Content Width For Single Column Lists
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/AppLayoutTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `AppLayoutTests.testRegularWidthUsesSplitChannelBrowserInLandscape`
- 概要: Regular Width Uses Split Channel Browser In Landscape
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/AppLayoutTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `AppLayoutTests.testRegularWidthUsesSplitChannelBrowserInPortrait`
- 概要: Regular Width Uses Split Channel Browser In Portrait
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/AppLayoutTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.003s`

- ID: `BasicGUICompositionTests.testBrowsePresentationFlagMatchesPresentationKind`
- 概要: Browse Presentation Flag Matches Presentation Kind
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `BasicGUICompositionTests.testCompactLayoutUsesCompactBasicGUIPresentation`
- 概要: Compact Layout Uses Compact Basic GUI Presentation
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `BasicGUICompositionTests.testRegularLayoutUsesSplitBasicGUIPresentation`
- 概要: Regular Layout Uses Split Basic GUI Presentation
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `BasicGUICompositionTests.testRouteAssemblyPreservesChannelListSortDescriptor`
- 概要: Route Assembly Preserves Channel List Sort Descriptor
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `BasicGUICompositionTests.testRouteAssemblyPreservesChannelVideosContext`
- 概要: Route Assembly Preserves Channel Videos Context
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `BasicGUICompositionTests.testRouteAssemblyPreservesRemoteSearchKeyword`
- 概要: Route Assembly Preserves Remote Search Keyword
- 分類: `logic` / `Layout`
- ファイル: `YoutubeFeederTests/Unit/Layout/BasicGUICompositionTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `FeedOrderingTests.testFreshnessClassifiesAge`
- 概要: Freshness Classifies Age
- 分類: `logic` / `Ordering`
- ファイル: `YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `FeedOrderingTests.testPrioritizesLatestPublishedThenOldestChecked`
- 概要: Prioritizes Latest Published Then Oldest Checked
- 分類: `logic` / `Ordering`
- ファイル: `YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `FeedOrderingTests.testPrioritizesRecentlySuccessfulChannelsWhenLatestPublishedMatches`
- 概要: Prioritizes Recently Successful Channels When Latest Published Matches
- 分類: `logic` / `Ordering`
- ファイル: `YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `FeedOrderingTests.testSortBrowseItemsByRegistrationDateAscending`
- 概要: Sort Browse Items By Registration Date Ascending
- 分類: `logic` / `Ordering`
- ファイル: `YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `FeedOrderingTests.testSortBrowseItemsByRegistrationDateDescending`
- 概要: Sort Browse Items By Registration Date Descending
- 分類: `logic` / `Ordering`
- ファイル: `YoutubeFeederTests/Unit/Ordering/FeedOrderingTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `ChannelRegistryCSVImportTests.testParserExtractsChannelIDsFromYouTubeExportCSV`
- 概要: Parser Extracts Channel I Ds From YouTube Export CSV
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistryCSVImportTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRegistryCSVImportTests.testParserRejectsEmptyFile`
- 概要: Parser Rejects Empty File
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistryCSVImportTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRegistryCSVImportTests.testParserRejectsInvalidUTF8`
- 概要: Parser Rejects Invalid UTF8
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistryCSVImportTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRegistryCSVImportTests.testParserRejectsMissingChannelID`
- 概要: Parser Rejects Missing Channel ID
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistryCSVImportTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRegistryCSVImportTests.testParserRejectsUnexpectedHeader`
- 概要: Parser Rejects Unexpected Header
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistryCSVImportTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRegistrySnapshotTests.testDecodeSupportsCurrentRegistryFormat`
- 概要: Decode Supports Current Registry Format
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `ChannelRegistrySnapshotTests.testExportIncludesRegisteredChannels`
- 概要: Export Includes Registered Channels
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.007s`

- ID: `ChannelRegistrySnapshotTests.testImportRestoresRegisteredChannels`
- 概要: Import Restores Registered Channels
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.007s`

- ID: `ChannelRegistrySnapshotTests.testLoadAllChannelIDsDoesNotRestoreFromLegacyCacheWhenRegistryIsMissing`
- 概要: Load All Channel I Ds Does Not Restore From Legacy Cache When Registry Is Missing
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.008s`

- ID: `ChannelRegistrySnapshotTests.testTransferDocumentDecodesCurrentFormat`
- 概要: Transfer Document Decodes Current Format
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRegistrySnapshotTests.testTransferRuntimeUsesOnDeviceBackupOnly`
- 概要: Transfer Runtime Uses On Device Backup Only
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRegistrySnapshotTests.testTransferStoreUsesLocalDocumentsFixedPath`
- 概要: Transfer Store Uses Local Documents Fixed Path
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/ChannelRegistrySnapshotTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `YouTubeChannelResolverTests.testChannelURLReturnsEmbeddedChannelID`
- 概要: Channel URL Returns Embedded Channel ID
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeChannelResolverTests.testDirectChannelIDReturnsAsIs`
- 概要: Direct Channel ID Returns As Is
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeChannelResolverTests.testExtractChannelIDReadsBrowseIDFromHTML`
- 概要: Extract Channel ID Reads Browse ID From HTML
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeChannelResolverTests.testExtractChannelIDReadsExternalIDFromHTML`
- 概要: Extract Channel ID Reads External ID From HTML
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeChannelResolverTests.testLookupURLTreatsPlainTextAsHandle`
- 概要: Lookup URL Treats Plain Text As Handle
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeChannelResolverTests.testNormalizedVideoURLExtractsWatchURL`
- 概要: Normalized Video URL Extracts Watch URL
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeChannelResolverTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeFeedParserTests.testUploadsPlaylistIDConvertsChannelID`
- 概要: Uploads Playlist ID Converts Channel ID
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeFeedParserTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeFeedParserTests.testYouTubeFeedParserParsesEntryMetadata`
- 概要: YouTube Feed Parser Parses Entry Metadata
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeFeedParserTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeSearchServiceTests.testFetchVideoDetailsContinuesConvertibleItemsAcrossBatchesWhenExcludedItemsPresent`
- 概要: Fetch Video Details Continues Convertible Items Across Batches When Excluded Items Present
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeSearchServiceTests.testFilterPlayableVideosExcludesItemsMissingDuration`
- 概要: Filter Playable Videos Excludes Items Missing Duration
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeSearchServiceTests.testFilterPlayableVideosExcludesLiveEntries`
- 概要: Filter Playable Videos Excludes Live Entries
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeSearchServiceTests.testMergeCandidatesKeepsLatestPublishedAtAndSortsDescending`
- 概要: Merge Candidates Keeps Latest Published At And Sorts Descending
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeSearchServiceTests.testVideoDetailsPartIncludesStatistics`
- 概要: Video Details Part Includes Statistics
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeSearchServiceTests.testVideoListResponseDecodesItemsWithMissingContentDetailsDuration`
- 概要: Video List Response Decodes Items With Missing Content Details Duration
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeSearchServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `YouTubeThumbnailCandidatesTests.testCandidateURLsFollowHighestToLowestOrder`
- 概要: Candidate UR Ls Follow Highest To Lowest Order
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeThumbnailCandidatesTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `YouTubeThumbnailCandidatesTests.testFilterPlayableVideosUsesVideoIDBasedThumbnailInsteadOfResponseThumbnail`
- 概要: Filter Playable Videos Uses Video ID Based Thumbnail Instead Of Response Thumbnail
- 分類: `logic` / `Parsing`
- ファイル: `YoutubeFeederTests/Unit/Parsing/YouTubeThumbnailCandidatesTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `BackSwipePolicyTests.testAcceptsHorizontalSwipeFromLeftEdge`
- 概要: Accepts Horizontal Swipe From Left Edge
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/BackSwipePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `BackSwipePolicyTests.testRejectsVerticalOrFarRightSwipe`
- 概要: Rejects Vertical Or Far Right Swipe
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/BackSwipePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRefreshSchedulePolicyTests.testNextRefreshDelayReturnsNilWhenThereAreNoChannels`
- 概要: Next Refresh Delay Returns Nil When There Are No Channels
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelRefreshSchedulePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRefreshSchedulePolicyTests.testNextRefreshDelayUsesEarliestPendingChannel`
- 概要: Next Refresh Delay Uses Earliest Pending Channel
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelRefreshSchedulePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRefreshSchedulePolicyTests.testPrioritizesDueChannelsByLatestPublishedAtDescending`
- 概要: Prioritizes Due Channels By Latest Published At Descending
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelRefreshSchedulePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelRefreshSchedulePolicyTests.testUsesOneHourIntervalForOlderChannels`
- 概要: Uses One Hour Interval For Older Channels
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelRefreshSchedulePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRefreshSchedulePolicyTests.testUsesTenMinuteIntervalForRecentChannels`
- 概要: Uses Ten Minute Interval For Recent Channels
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelRefreshSchedulePolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelVideosAutoRefreshPolicyTests.testRemoteSearchRequiresRefreshWhenOnlyOneCachedVideoExists`
- 概要: Remote Search Requires Refresh When Only One Cached Video Exists
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelVideosAutoRefreshPolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelVideosAutoRefreshPolicyTests.testRequiresRefreshWhenChannelHasNoCachedVideosYet`
- 概要: Requires Refresh When Channel Has No Cached Videos Yet
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelVideosAutoRefreshPolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `ChannelVideosAutoRefreshPolicyTests.testRequiresRefreshWhenSelectedVideoIsMissingFromChannelCache`
- 概要: Requires Refresh When Selected Video Is Missing From Channel Cache
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelVideosAutoRefreshPolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelVideosAutoRefreshPolicyTests.testSkipsRefreshWhenSelectedVideoAlreadyExistsInChannelCache`
- 概要: Skips Refresh When Selected Video Already Exists In Channel Cache
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/ChannelVideosAutoRefreshPolicyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `RemoteSearchErrorPolicyTests.testDiagnosticReasonRecognizesURLSessionCancellation`
- 概要: Diagnostic Reason Recognizes URL Session Cancellation
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/RemoteSearchErrorPolicyTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.002s`

- ID: `RemoteSearchErrorPolicyTests.testUserMessagePreservesOrdinaryErrorDescription`
- 概要: User Message Preserves Ordinary Error Description
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/RemoteSearchErrorPolicyTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `RemoteSearchErrorPolicyTests.testUserMessageSuppressesCancellationError`
- 概要: User Message Suppresses Cancellation Error
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/RemoteSearchErrorPolicyTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `VideoSharePolicyTests.testShareURLReturnsNilWhenVideoURLIsMissing`
- 概要: Share URL Returns Nil When Video URL Is Missing
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/VideoSharePolicyTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.000s`

- ID: `VideoSharePolicyTests.testShareURLReturnsVideoURLWhenAvailable`
- 概要: Share URL Returns Video URL When Available
- 分類: `logic` / `Policies`
- ファイル: `YoutubeFeederTests/Unit/Policies/VideoSharePolicyTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.001s`

- ID: `ChannelRegistryCSVImportServiceTests.testImportAppendsOnlyNewChannelIDsAndReportsCounts`
- 概要: Import Appends Only New Channel I Ds And Reports Counts
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/ChannelRegistryCSVImportServiceTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.007s`

- ID: `ChannelRegistryCloudflareSyncServiceTests.testChannelRegistryEndpointURLAcceptsBaseURL`
- 概要: Channel Registry Endpoint URL Accepts Base URL
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/ChannelRegistryCloudflareSyncServiceTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.001s`

- ID: `ChannelRegistryCloudflareSyncServiceTests.testChannelRegistryEndpointURLDoesNotDuplicatePath`
- 概要: Channel Registry Endpoint URL Does Not Duplicate Path
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/ChannelRegistryCloudflareSyncServiceTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.002s`

- ID: `ChannelRegistryCloudflareSyncServiceTests.testSyncChannelRegistryEncodesRecordsAndPostsToWorker`
- 概要: Sync Channel Registry Encodes Records And Posts To Worker
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/ChannelRegistryCloudflareSyncServiceTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.057s`

- ID: `ChannelRegistryCloudflareSyncServiceTests.testSyncChannelRegistryThrowsForHTTPFailureWithoutMutatingStore`
- 概要: Sync Channel Registry Throws For HTTP Failure Without Mutating Store
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/ChannelRegistryCloudflareSyncServiceTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.014s`

- ID: `FeedCacheCoordinatorConcurrencyTests.testMaximumConcurrentChannelRefreshesRemainsThree`
- 概要: Maximum Concurrent Channel Refreshes Remains Three
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorConcurrencyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.000s`

- ID: `FeedCacheCoordinatorConcurrencyTests.testSyncRegisteredChannelsFromStoreRestoresEmptyInMemoryChannels`
- 概要: Sync Registered Channels From Store Restores Empty In Memory Channels
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorConcurrencyTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.006s`

- ID: `FeedCacheCoordinatorRemoteSearchTests.testForceRefreshCompletesRemoteRefreshWhenVideoDetailsContainExcludedItems`
- 概要: Force Refresh Completes Remote Refresh When Video Details Contain Excluded Items
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:10`
- 所要時間: `0.014s`

- ID: `FeedCacheCoordinatorRemoteSearchTests.testForceRefreshPersistsEvenIfCallerTaskIsCancelled`
- 概要: Force Refresh Persists Even If Caller Task Is Cancelled
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift`
- 開始: `10:45:10`
- 終了: `10:45:12`
- 所要時間: `2.247s`

- ID: `FeedCacheCoordinatorRemoteSearchTests.testForceRefreshPersistsRemoteSearchResultToCache`
- 概要: Force Refresh Persists Remote Search Result To Cache
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift`
- 開始: `10:45:12`
- 終了: `10:45:13`
- 所要時間: `1.026s`

- ID: `FeedCacheCoordinatorRemoteSearchTests.testLoadVideosForChannelDeduplicatesSameVideoIDAcrossFeedCacheAndRemoteSearch`
- 概要: Load Videos For Channel Deduplicates Same Video ID Across Feed Cache And Remote Search
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift`
- 開始: `10:45:13`
- 終了: `10:45:13`
- 所要時間: `0.014s`

- ID: `FeedCacheCoordinatorRemoteSearchTests.testOpenChannelVideosUsesChannelFallbackWhenRemoteSearchHasOnlyOneVideo`
- 概要: Open Channel Videos Uses Channel Fallback When Remote Search Has Only One Video
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheCoordinatorRemoteSearchTests.swift`
- 開始: `10:45:13`
- 終了: `10:45:15`
- 所要時間: `2.056s`

- ID: `FeedCacheMaintenanceTests.testCacheThumbnailFallsBackToNextCandidateAndPersistsFilename`
- 概要: Cache Thumbnail Falls Back To Next Candidate And Persists Filename
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.012s`

- ID: `FeedCacheMaintenanceTests.testCacheThumbnailForCachedVideoUsesVideoIDCandidatesAndPersistsFilename`
- 概要: Cache Thumbnail For Cached Video Uses Video ID Candidates And Persists Filename
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.007s`

- ID: `FeedCacheMaintenanceTests.testConsistencyMaintenanceRemovesDetachedVideosAndThumbnails`
- 概要: Consistency Maintenance Removes Detached Videos And Thumbnails
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.009s`

- ID: `FeedCacheMaintenanceTests.testCurrentThumbnailCacheStatusReportsBytesAndThresholdJudgement`
- 概要: Current Thumbnail Cache Status Reports Bytes And Threshold Judgement
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.009s`

- ID: `FeedCacheMaintenanceTests.testEvictOldestThumbnailIfNeededRemovesLeastRecentlyAccessedFileFirst`
- 概要: Evict Oldest Thumbnail If Needed Removes Least Recently Accessed File First
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.007s`

- ID: `FeedCacheMaintenanceTests.testFeedSnapshotPersistsThumbnailLastAccessedAt`
- 概要: Feed Snapshot Persists Thumbnail Last Accessed At
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.005s`

- ID: `FeedCacheMaintenanceTests.testLoadVideosMasksUnderFourMinuteVideosAsShorts`
- 概要: Load Videos Masks Under Four Minute Videos As Shorts
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.005s`

- ID: `FeedCacheMaintenanceTests.testRecordThumbnailReferenceUpdatesFeedAndRemoteSearchRows`
- 概要: Record Thumbnail Reference Updates Feed And Remote Search Rows
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.005s`

- ID: `FeedCacheMaintenanceTests.testRemoveChannelIDDeletesRegisteredChannel`
- 概要: Remove Channel ID Deletes Registered Channel
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.005s`

- ID: `FeedCacheMaintenanceTests.testResetAllStoredDataClearsCacheButLeavesBackupRecoverable`
- 概要: Reset All Stored Data Clears Cache But Leaves Backup Recoverable
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.013s`

- ID: `FeedCacheMaintenanceTests.testTrimThumbnailsIfNeededContinuesUntilBelowLowWatermark`
- 概要: Trim Thumbnails If Needed Continues Until Below Low Watermark
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheMaintenanceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.008s`

- ID: `FeedCacheReadWriteServiceTests.testClearRemoteSearchRemovesPersistedCacheThroughWriteService`
- 概要: Clear Remote Search Removes Persisted Cache Through Write Service
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheReadWriteServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`

- ID: `FeedCacheReadWriteServiceTests.testLoadMergedVideosForChannelDoesNotMutateCaches`
- 概要: Load Merged Videos For Channel Does Not Mutate Caches
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheReadWriteServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.007s`

- ID: `FeedCacheReadWriteServiceTests.testLoadRefreshStateDoesNotPersistBootstrap`
- 概要: Load Refresh State Does Not Persist Bootstrap
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheReadWriteServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`

- ID: `FeedCacheReadWriteServiceTests.testLoadRemoteSearchSnapshotReadsCacheWithoutMutatingEntries`
- 概要: Load Remote Search Snapshot Reads Cache Without Mutating Entries
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheReadWriteServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.007s`

- ID: `FeedCacheReadWriteServiceTests.testPersistBootstrapWritesSnapshotThroughWriteService`
- 概要: Persist Bootstrap Writes Snapshot Through Write Service
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/FeedCacheReadWriteServiceTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`

- ID: `RemoteVideoSearchCacheStoreTests.testClearAllRemovesDefaultAndSanitizedSearchCacheFiles`
- 概要: Clear All Removes Default And Sanitized Search Cache Files
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.008s`

- ID: `RemoteVideoSearchCacheStoreTests.testMergeKeepsExistingVideosAndAddsNewOnes`
- 概要: Merge Keeps Existing Videos And Adds New Ones
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`

- ID: `RemoteVideoSearchCacheStoreTests.testRemoteSearchCachePersistsThumbnailLastAccessedAt`
- 概要: Remote Search Cache Persists Thumbnail Last Accessed At
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`

- ID: `RemoteVideoSearchCacheStoreTests.testRemoteSearchCacheStatusReflectsFreshnessWindow`
- 概要: Remote Search Cache Status Reflects Freshness Window
- 分類: `logic` / `Storage`
- ファイル: `YoutubeFeederTests/Unit/Storage/RemoteVideoSearchCacheStoreTests.swift`
- 開始: `10:45:15`
- 終了: `10:45:15`
- 所要時間: `0.006s`


### UI Tests
- ID: `HomeScreenUITests.testAppLaunchesWithoutCrashing`
- 概要: App Launches Without Crashing
- 分類: `ui` / `Home`
- ファイル: `YoutubeFeederUITests/Home/HomeScreenUITests.swift`
- 開始: `10:45:22`
- 終了: `10:45:26`
- 所要時間: `3.708s`

- ID: `HomeScreenUITests.testHomeScreenAppearsAfterLaunch`
- 概要: Home Screen Appears After Launch
- 分類: `ui` / `Home`
- ファイル: `YoutubeFeederUITests/Home/HomeScreenUITests.swift`
- 開始: `10:45:26`
- 終了: `10:45:31`
- 所要時間: `4.616s`
