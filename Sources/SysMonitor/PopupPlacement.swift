import Foundation

enum PopupPlacement {
    static func frame(contentSize: CGSize, button: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(contentSize.width, visibleFrame.width)
        let height = min(contentSize.height, visibleFrame.height)
        let x = min(max(button.midX - width / 2, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(button.minY - height - 5, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
