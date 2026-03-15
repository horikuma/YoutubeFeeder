import Foundation

enum MaintenanceRoute: Hashable {
    case channelList
    case allVideos
    case channelRegistration
    case channelVideos(String)
}
