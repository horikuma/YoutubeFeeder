import SwiftUI

struct AppLayout {
    let isPad: Bool
    let isLandscape: Bool
    let usesRegularWidth: Bool
    let usesSplitChannelBrowser: Bool
    let contentWidth: CGFloat?
    let readableContentWidth: CGFloat?
    let horizontalPadding: CGFloat
    let sectionSpacing: CGFloat
    let listColumns: [GridItem]
    let dashboardColumns: [GridItem]

    static func current(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> AppLayout {
        let isLandscape = size.width > size.height
        let usesRegularWidth = horizontalSizeClass == .regular
        let usesSplitChannelBrowser = usesRegularWidth

        if usesRegularWidth {
            return AppLayout(
                isPad: true,
                isLandscape: isLandscape,
                usesRegularWidth: true,
                usesSplitChannelBrowser: usesSplitChannelBrowser,
                contentWidth: usesSplitChannelBrowser ? 1280 : 1080,
                readableContentWidth: 920,
                horizontalPadding: 28,
                sectionSpacing: 22,
                listColumns: [GridItem(.flexible(), spacing: 20, alignment: .top)],
                dashboardColumns: [
                    GridItem(.flexible(), spacing: 18, alignment: .top),
                    GridItem(.flexible(), spacing: 18, alignment: .top)
                ]
            )
        }

        return AppLayout(
            isPad: false,
            isLandscape: isLandscape,
            usesRegularWidth: false,
            usesSplitChannelBrowser: false,
            contentWidth: nil,
            readableContentWidth: nil,
            horizontalPadding: 16,
            sectionSpacing: 16,
            listColumns: [GridItem(.flexible(), spacing: 14, alignment: .top)],
            dashboardColumns: [GridItem(.flexible(), spacing: 16, alignment: .top)]
        )
    }
}
