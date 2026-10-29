import AppKit

enum PopupPosition: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, center

    var symbolName: String {
        switch self {
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .center: "rectangle.center.inset.filled"
        }
    }

    var title: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .center: "Center"
        }
    }

    func origin(for size: NSSize, in frame: NSRect) -> NSPoint {
        let margin: CGFloat = 16
        let maxX = max(frame.minX, frame.maxX - size.width)
        let maxY = max(frame.minY, frame.maxY - size.height)
        let left = min(frame.minX + margin, maxX)
        let right = max(frame.minX, maxX - margin)
        let bottom = min(frame.minY + margin, maxY)
        let top = max(frame.minY, maxY - margin)
        switch self {
        case .topLeft: return NSPoint(x: left, y: top)
        case .topRight: return NSPoint(x: right, y: top)
        case .bottomLeft: return NSPoint(x: left, y: bottom)
        case .bottomRight: return NSPoint(x: right, y: bottom)
        case .center:
            return NSPoint(x: min(max(frame.midX - size.width / 2, frame.minX), maxX),
                           y: min(max(frame.midY - size.height / 2, frame.minY), maxY))
        }
    }
}
