import Foundation
import Testing
@testable import SysMonitor

@Test func popupStaysInsideEitherScreenEdge() {
    let screen = CGRect(x: 0, y: 0, width: 1_280, height: 770)
    for x: CGFloat in [0, 1_116] {
        let frame = PopupPlacement.frame(contentSize: CGSize(width: 300, height: 560),
                                         button: CGRect(x: x, y: 770, width: 164, height: 24), visibleFrame: screen)
        #expect(screen.contains(frame))
    }
}

@Test func popupUsesTheStatusItemsScreenAndCapsItsHeight() {
    let screen = CGRect(x: -1_024, y: 300, width: 1_024, height: 500)
    let frame = PopupPlacement.frame(contentSize: CGSize(width: 300, height: 1_133),
                                     button: CGRect(x: -164, y: 800, width: 164, height: 24), visibleFrame: screen)
    #expect(screen.contains(frame))
    #expect(frame.height == 500)
    #expect(frame.maxX == 0)
}
