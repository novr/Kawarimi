// Layout contract for detail column (#117): safeAreaInset toolbar, header scroll, no layoutPriority(0) on header alone.
// Automated tests here cover numeric metrics only; SwiftUI hierarchy regressions need manual checks.

import Testing
@testable import KawarimiHengeCore

@Test func detailColumnBottomToolbarHeightTightVsRegular() {
    #expect(DetailColumnLayoutCore.bottomToolbarHeight(tightVertical: true) == 76)
    #expect(DetailColumnLayoutCore.bottomToolbarHeight(tightVertical: false) == 92)
}
