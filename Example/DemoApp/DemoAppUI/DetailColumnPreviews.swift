#if DEBUG
@_spi(Preview) import KawarimiHenge
import SwiftUI

#Preview("Detail column — sparse metadata") {
    let fixture = DetailColumnPreviewFixtures.sparseChrome
    DetailColumnPreviewCanvas.chrome(
        endpoint: fixture.endpoint,
        initialMock: fixture.initialMock,
        securityCatalog: fixture.securityCatalog
    )
}

#Preview("Detail column — security heavy") {
    let fixture = DetailColumnPreviewFixtures.securityHeavyChrome
    DetailColumnPreviewCanvas.chrome(
        endpoint: fixture.endpoint,
        initialMock: fixture.initialMock,
        securityCatalog: fixture.securityCatalog
    )
}

#Preview("Detail column — long JSON") {
    let fixture = DetailColumnPreviewFixtures.longJSONChrome
    DetailColumnPreviewCanvas.chrome(
        endpoint: fixture.endpoint,
        initialMock: fixture.initialMock,
        securityCatalog: fixture.securityCatalog
    )
}

#Preview("Detail column header — sparse") {
    let fixture = DetailColumnPreviewFixtures.sparseHeader
    DetailColumnPreviewCanvas.header(
        endpoint: fixture.endpoint,
        initialMock: fixture.initialMock,
        securityCatalog: fixture.securityCatalog
    )
}

#Preview("Detail column toolbar — tight") {
    DetailColumnPreviewCanvas.toolbarTight()
}
#endif
