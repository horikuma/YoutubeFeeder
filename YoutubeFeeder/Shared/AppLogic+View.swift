import SwiftUI

extension View {
    func bindRefreshCommand(_ action: (() async -> Void)?) -> some View {
        modifier(RefreshCommandRegistrationModifier(action: action))
    }
}
