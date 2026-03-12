import SwiftUI

struct AppLayout {
    let isPad: Bool
    let contentWidth: CGFloat?
    let horizontalPadding: CGFloat
    let sectionSpacing: CGFloat
    let listColumns: [GridItem]
    let dashboardColumns: [GridItem]
    let tileHeight: CGFloat

    static func current(horizontalSizeClass: UserInterfaceSizeClass?, idiom: UIUserInterfaceIdiom) -> AppLayout {
        let isPad = idiom == .pad || horizontalSizeClass == .regular

        if isPad {
            return AppLayout(
                isPad: true,
                contentWidth: 1080,
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
            contentWidth: nil,
            horizontalPadding: 16,
            sectionSpacing: 16,
            listColumns: [GridItem(.flexible(), spacing: 14, alignment: .top)],
            dashboardColumns: [GridItem(.flexible(), spacing: 16, alignment: .top)],
            tileHeight: 220
        )
    }
}
