import Testing
@testable import KawarimiHengeCore

@Test func navigationLayoutCompactWhenHorizontalCompact() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: true, verticalIsCompact: false, platformIsIOS: false) == true)
}

@Test func navigationLayoutCompactWhenVerticalCompactOnIOS() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: true, platformIsIOS: true) == true)
}

@Test func navigationLayoutNotCompactWhenBothRegularOnIOS() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: false, platformIsIOS: true) == false)
}

@Test func navigationLayoutNilSizeClassesAreNotCompactOnMac() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: false, platformIsIOS: false) == false)
}

@Test func explorerTightVerticalOnlyOnIOSCompactVertical() {
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: true, platformIsIOS: true) == true)
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: false, platformIsIOS: true) == false)
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: true, platformIsIOS: false) == false)
}
