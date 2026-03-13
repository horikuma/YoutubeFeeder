import SwiftUI

struct AppLayout {
    let isPad: Bool
    let isLandscape: Bool
    let usesSplitChannelBrowser: Bool
    let contentWidth: CGFloat?
    let horizontalPadding: CGFloat
    let sectionSpacing: CGFloat
    let listColumns: [GridItem]
    let dashboardColumns: [GridItem]
    let tileHeight: CGFloat

    static func current(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?, idiom: UIUserInterfaceIdiom) -> AppLayout {
        let isPad = idiom == .pad || horizontalSizeClass == .regular
        let isLandscape = size.width > size.height
        let usesSplitChannelBrowser = isPad && isLandscape

        if isPad {
            return AppLayout(
                isPad: true,
                isLandscape: isLandscape,
                usesSplitChannelBrowser: usesSplitChannelBrowser,
                contentWidth: usesSplitChannelBrowser ? 1280 : 1080,
                horizontalPadding: 28,
                sectionSpacing: 22,
                listColumns: [
                    GridItem(.flexible(), spacing: 20, alignment: .top),
                    GridItem(.flexible(), spacing: 20, alignment: .top),
                ],
                dashboardColumns: [
                    GridItem(.flexible(), spacing: 18, alignment: .top),
                    GridItem(.flexible(), spacing: 18, alignment: .top),
                ],
                tileHeight: 260
            )
        }

        return AppLayout(
            isPad: false,
            isLandscape: isLandscape,
            usesSplitChannelBrowser: false,
            contentWidth: nil,
            horizontalPadding: 16,
            sectionSpacing: 16,
            listColumns: [GridItem(.flexible(), spacing: 14, alignment: .top)],
            dashboardColumns: [GridItem(.flexible(), spacing: 16, alignment: .top)],
            tileHeight: 220
        )
    }
}
