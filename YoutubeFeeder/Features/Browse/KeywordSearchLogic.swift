struct KeywordSearchLogic: Hashable {
    var result: VideoSearchResult = VideoSearchResult(keyword: "", videos: [], totalCount: 0)

    mutating func setResult(_ result: VideoSearchResult) {
        self.result = result
    }
}
