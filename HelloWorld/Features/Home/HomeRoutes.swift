import Foundation

enum MaintenanceRoute: Hashable {
    case channelList(ChannelBrowseSortDescriptor)
    case allVideos
    case keywordSearchResults(String)
    case channelRegistration
    case channelVideos(String)
}
