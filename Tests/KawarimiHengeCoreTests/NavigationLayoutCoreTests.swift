import Testing
@testable import KawarimiHengeCore

@Test(.timeLimit(.minutes(1))) func navigationLayoutCompactWhenHorizontalCompact() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: true, verticalIsCompact: false, platformIsIOS: false) == true)
}

@Test(.timeLimit(.minutes(1))) func navigationLayoutCompactWhenVerticalCompactOnIOS() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: true, platformIsIOS: true) == true)
}

@Test(.timeLimit(.minutes(1))) func navigationLayoutNotCompactWhenBothRegularOnIOS() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: false, platformIsIOS: true) == false)
}

@Test(.timeLimit(.minutes(1))) func navigationLayoutNilSizeClassesAreNotCompactOnMac() {
    #expect(NavigationLayoutCore.useCompactNavigation(horizontalIsCompact: false, verticalIsCompact: false, platformIsIOS: false) == false)
}

@Test(.timeLimit(.minutes(1))) func explorerTightVerticalOnlyOnIOSCompactVertical() {
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: true, platformIsIOS: true) == true)
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: false, platformIsIOS: true) == false)
    #expect(NavigationLayoutCore.explorerTightVertical(verticalIsCompact: true, platformIsIOS: false) == false)
}
