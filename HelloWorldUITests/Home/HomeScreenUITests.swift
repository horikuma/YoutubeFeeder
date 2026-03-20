import XCTest

final class HomeScreenUITests: UITestCaseSupport {
    func testHomePrimaryNavigationAndFeedbackFlow() throws {
        let app = launchApp()

        waitForHomeScreen(in: app)
        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.videos", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.search", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.remoteSearch", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.performanceProbe", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.channelRegistration", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.registryTransfer", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.resetAllSettings", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("home.systemStatus", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["バックアップ"].waitForExistence(timeout: 3))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "bootstrapLoaded", in: timeline), 2000)
        XCTAssertLessThan(try offset(for: "maintenanceShown", in: timeline), 2500)
        let startupMetrics = try startupMetrics(from: timeline)
        let payload = [
            "timeline": timeline,
            "startup_metrics": startupMetrics,
        ] as [String : Any]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("HELLOWORLD_STARTUP_METRICS \(text)")
        }
        try writeJSONIfRequested(
            payload,
            environmentKey: "HELLOWORLD_STARTUP_METRICS_OUTPUT"
        )
        element("nav.channels", in: app).tap()

        XCTAssertTrue(app.buttons["動画投稿日時 ↓"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["チャンネル登録日時 ↓"].waitForExistence(timeout: 3))
        app.buttons["動画投稿日時 ↓"].tap()

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["動画投稿日時が新しい順"].waitForExistence(timeout: 3))

        swipeBack(in: app)
        waitForHomeScreen(in: app, timeout: 3)

        element("nav.remoteSearch", in: app).tap()
        XCTAssertTrue(app.staticTexts["下に引っ張ると「ゆっくり実況」を YouTube で検索し、履歴を順次マージして表示"].waitForExistence(timeout: 3))

        let searchScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(searchScrollView.waitForExistence(timeout: 3))
        searchScrollView.swipeUp()
        XCTAssertTrue(eventually(timeout: 3) {
            !self.element("search.resultChip", in: app).exists
        })

        swipeBack(in: app)
        waitForHomeScreen(in: app, timeout: 3)

        element("nav.channelRegistration", in: app).tap()
        XCTAssertTrue(element("channelRegistration.input", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("channelRegistration.submit", in: app).waitForExistence(timeout: 3))
    }

    func testHomeRefreshUsesMockPathWithoutNetwork() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_AUTO_REFRESH": "1"])

        waitForHomeScreen(in: app)
        XCTAssertTrue(eventually(timeout: 5) {
            guard let timeline = self.timelinePayloadIfAvailable(in: app) else {
                return false
            }
            return timeline["manualRefreshFinished"] != nil
        })
    }

    func testRemoteSearchHomeNavigationSplitMetricsBaseline() throws {
        try measureRemoteSearchHomeNavigationMetrics(fixtureVariant: "baseline")
    }

    func testRemoteSearchHomeNavigationSplitMetricsHeavyFixture() throws {
        try measureRemoteSearchHomeNavigationMetrics(fixtureVariant: "heavy")
    }

    func testRemoteSearchHomeNavigationSplitMetricsStandardProbe() throws {
        try measureRemoteSearchHomeNavigationMetrics(
            fixtureVariant: "baseline",
            probeMode: "E"
        )
    }

    private func measureRemoteSearchHomeNavigationMetrics(
        fixtureVariant: String,
        probeMode: String = "A"
    ) throws {
        let app = launchApp(
            extraEnvironment: [
                "HELLOWORLD_RUNTIME_LOGGING": "1",
                "HELLOWORLD_UI_TEST_REMOTE_SEARCH_FIXTURE": fixtureVariant,
                "HELLOWORLD_UI_TEST_PROBE_MODE": probeMode,
            ]
        )

        waitForHomeScreen(in: app, timeout: 8)
        let timeline = try timelinePayload(in: app)
        let startup = try startupMetrics(from: timeline)
        XCTAssertTrue(element("nav.remoteSearch", in: app).waitForExistence(timeout: 3))

        element("nav.remoteSearch", in: app).tap()

        guard element("screen.remoteSearchSplitTitle", in: app).waitForExistence(timeout: 10) else {
            throw XCTSkip("split metrics は iPad split layout 専用")
        }
        XCTAssertTrue(eventually(timeout: 10, pollInterval: 0.25) {
            guard let payload = self.runtimePayloadIfAvailable(in: app) else {
                return false
            }
            return self.firstRuntimeEntry(named: "remote_search_split_load_completed", in: payload) != nil
        })

        let payload = try runtimePayload(in: app)
        let tapEntry = try XCTUnwrap(firstRuntimeEntry(named: "remote_search_home_tapped", in: payload))
        let screenEntry = try XCTUnwrap(firstRuntimeEntry(named: "remote_search_screen_shown", in: payload))
        let scheduledEntry = try XCTUnwrap(firstRuntimeEntry(named: "remote_search_split_load_scheduled", in: payload))
        let startedEntry = try XCTUnwrap(firstRuntimeEntry(named: "remote_search_split_load_started", in: payload))
        let completedEntry = try XCTUnwrap(firstRuntimeEntry(named: "remote_search_split_load_completed", in: payload))

        let metrics: [String: Any] = [
            "fixture": fixtureVariant,
            "probe_mode": probeMode,
            "app_launch_to_splash_ms": startup["app_launch_to_splash_ms"] ?? 0,
            "app_launch_to_home_ms": startup["app_launch_to_home_ms"] ?? 0,
            "app_launch_to_maintenance_enter_ms": startup["app_launch_to_maintenance_enter_ms"] ?? 0,
            "home_tap_to_screen_ms": try millisecondsBetween(tapEntry, and: screenEntry),
            "screen_to_split_schedule_ms": try millisecondsBetween(screenEntry, and: scheduledEntry),
            "screen_to_split_start_ms": try millisecondsBetween(screenEntry, and: startedEntry),
            "split_load_ms": try millisecondsBetween(startedEntry, and: completedEntry),
            "home_tap_to_split_loaded_ms": try millisecondsBetween(tapEntry, and: completedEntry),
            "split_loaded_videos": completedEntry.metadata["videos"] ?? "0",
            "split_trigger": completedEntry.metadata["trigger"] ?? "",
        ]

        if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("HELLOWORLD_REMOTE_SEARCH_SPLIT_METRICS \(text)")
        }

        XCTAssertEqual(completedEntry.metadata["trigger"], "initial")
        XCTAssertEqual(screenEntry.metadata["probe_mode"], probeMode)
        XCTAssertGreaterThan(Int(completedEntry.metadata["videos"] ?? "0") ?? 0, 0)
        XCTAssertGreaterThanOrEqual(metrics["home_tap_to_screen_ms"] as? Int ?? -1, 0)
        XCTAssertGreaterThanOrEqual(metrics["split_load_ms"] as? Int ?? -1, 0)
    }
}
