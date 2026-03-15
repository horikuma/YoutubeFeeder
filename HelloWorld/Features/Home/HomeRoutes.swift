import Foundation

enum MaintenanceRoute: Hashable {
    case channelList(ChannelBrowseSortDescriptor)
    case allVideos
    case channelRegistration
    case channelVideos(String)
}
