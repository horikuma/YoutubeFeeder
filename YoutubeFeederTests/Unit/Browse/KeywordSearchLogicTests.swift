import XCTest
@testable import YoutubeFeeder

final class KeywordSearchLogicTests: LoggedTestCase {
    func testDefaultsStartEmpty() {
        let state = KeywordSearchLogic()

        XCTAssertEqual(state.result.keyword, "")
        XCTAssertTrue(state.result.videos.isEmpty)
        XCTAssertEqual(state.result.totalCount, 0)
        XCTAssertEqual(state.result.source, .localCache)
        XCTAssertNil(state.result.fetchedAt)
        XCTAssertNil(state.result.expiresAt)
        XCTAssertNil(state.result.errorMessage)
    }

    func testSetResultReplacesCurrentResult() {
        var state = KeywordSearchLogic()
        let result = makeResult(
            keyword: "swift",
            totalCount: 2,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000),
            errorMessage: nil
        )

        state.setResult(result)

        XCTAssertEqual(state.result, result)
    }

    private func makeResult(
        keyword: String,
        totalCount: Int,
        fetchedAt: Date?,
        errorMessage: String?
    ) -> VideoSearchResult {
        VideoSearchResult(
            keyword: keyword,
            videos: [],
            totalCount: totalCount,
            fetchedAt: fetchedAt,
            errorMessage: errorMessage
        )
    }
}
