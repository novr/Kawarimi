import SwiftUI
import Testing
@testable import KawarimiHenge

@Test func navigationLayoutCompactWhenHorizontalCompact() {
    #expect(NavigationLayoutLogic.useCompactNavigation(horizontal: .compact, vertical: .regular) == true)
}

@Test func navigationLayoutCompactWhenVerticalCompactEvenIfHorizontalRegular() {
    #if os(iOS)
    #expect(NavigationLayoutLogic.useCompactNavigation(horizontal: .regular, vertical: .compact) == true)
    #else
    #expect(NavigationLayoutLogic.useCompactNavigation(horizontal: .regular, vertical: .compact) == false)
    #endif
}

@Test func navigationLayoutNotCompactWhenBothRegular() {
    #expect(NavigationLayoutLogic.useCompactNavigation(horizontal: .regular, vertical: .regular) == false)
}

@Test func navigationLayoutNilSizeClassesAreNotCompact() {
    #expect(NavigationLayoutLogic.useCompactNavigation(horizontal: nil, vertical: nil) == false)
}

@Test func explorerTightVerticalOnlyOnIOSCompactVertical() {
    #if os(iOS)
    #expect(NavigationLayoutLogic.explorerTightVertical(vertical: .compact) == true)
    #expect(NavigationLayoutLogic.explorerTightVertical(vertical: .regular) == false)
    #expect(NavigationLayoutLogic.explorerTightVertical(vertical: nil) == false)
    #else
    #expect(NavigationLayoutLogic.explorerTightVertical(vertical: .compact) == false)
    #endif
}
