import Foundation

enum MaintenanceRoute: Hashable {
    case channelList(ChannelBrowseSortDescriptor)
    case allVideos
    case keywordSearchResults(String)
    case remoteKeywordSearchResults(String)
    case channelRegistration
    case channelVideos(String)
}
