#if DEBUG
import KawarimiHenge
import SwiftUI

#Preview("Detail column — sparse metadata") {
    DetailColumnChromePreviewRoot(.sparseMetadata)
}

#Preview("Detail column — security heavy") {
    DetailColumnChromePreviewRoot(.securityHeavy)
}

#Preview("Detail column — long JSON") {
    DetailColumnChromePreviewRoot(.longJSON)
}

#Preview("Detail column header — sparse") {
    DetailColumnHeaderPreviewRoot()
}

#Preview("Detail column toolbar — tight") {
    DetailColumnToolbarPreviewRoot()
}
#endif
