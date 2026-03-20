import XCTest
@testable import HelloWorld

final class PerformanceProbeModeTests: XCTestCase {
    func testDefaultProbeModeIsAWhenNothingStored() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PerformanceProbeMode.storageKey)

        XCTAssertEqual(PerformanceProbeMode.current, .modeA)
    }

    func testProbeModeProfilesExposeExpectedCharacteristics() {
        XCTAssertEqual(PerformanceProbeMode.modeA.splitLoadDelayMilliseconds, 150)
        XCTAssertEqual(PerformanceProbeMode.modeB.splitLoadDelayMilliseconds, 0)
        XCTAssertEqual(PerformanceProbeMode.modeC.initialRemoteSearchSnapshotLimit, 20)
        XCTAssertFalse(PerformanceProbeMode.modeD.allowsAutomaticInitialSplitLoad)
        XCTAssertTrue(PerformanceProbeMode.modeE.usesStandardRemoteSearchSplitUI)
        XCTAssertEqual(PerformanceProbeMode.modeE.initialRemoteSearchSnapshotLimit, 100)
    }
}
