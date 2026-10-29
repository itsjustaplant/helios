import AppKit

private final class CenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let original = super.drawingRect(forBounds: rect)
        let height = min(cellSize(forBounds: original).height, original.height)
        return NSRect(x: original.minX, y: original.midY - height / 2, width: original.width, height: height)
    }
}

@MainActor
final class InputRow: NSView {
    private static let activeColor = NSColor(srgbRed: 0.36, green: 0.32, blue: 0.72, alpha: 1)
    private static let confirmedColor = NSColor(srgbRed: 0.13, green: 0.50, blue: 0.31, alpha: 1)
    var onClick: (() -> Void)?
    private let fill = CALayer()
    private let title = NSTextField(labelWithString: "")
    private let number = NSTextField(labelWithString: "")
    private let marker = NSTextField(labelWithString: "Current")
    private let enterBadge = NSTextField(labelWithString: "")
    private let progressText = NSView()
    private let progressTextMask = CALayer()
    private var whiteMarker: NSTextField?
    private var progressNumber: NSTextField?
    private var whiteEnterBadge: NSTextField?

    init(frame: NSRect, title text: String) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.addSublayer(fill)
        fill.backgroundColor = Self.activeColor.cgColor
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        number.cell = CenteredTextFieldCell(textCell: parts.first.map(String.init) ?? "")
        number.alignment = .center
        number.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        number.textColor = NSColor(calibratedWhite: 0.3, alpha: 1)
        number.wantsLayer = true
        number.layer?.backgroundColor = NSColor(srgbRed: 0.925, green: 0.929, blue: 0.945, alpha: 1).cgColor
        number.layer?.cornerRadius = 6
        number.layer?.borderWidth = 1
        number.layer?.borderColor = NSColor(calibratedWhite: 0.76, alpha: 1).cgColor
        number.frame = NSRect(x: 12, y: 10, width: 24, height: 24)
        number.cell?.isScrollable = false
        number.cell?.wraps = false
        addSubview(number)
        title.stringValue = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : text
        title.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        title.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        title.frame = NSRect(x: 48, y: 12, width: 166, height: 20)
        addSubview(title)
        marker.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        marker.textColor = NSColor(calibratedWhite: 0.40, alpha: 1)
        marker.alignment = .right
        marker.frame = NSRect(x: 214, y: 13, width: 62, height: 18)
        addSubview(marker)
        enterBadge.cell = CenteredTextFieldCell(textCell: "↵")
        enterBadge.font = .systemFont(ofSize: 15, weight: .medium)
        enterBadge.alignment = .center
        enterBadge.textColor = NSColor(calibratedWhite: 0.3, alpha: 1)
        enterBadge.frame = NSRect(x: 252, y: 10, width: 24, height: 24)
        enterBadge.wantsLayer = true
        enterBadge.layer?.backgroundColor = number.layer?.backgroundColor
        enterBadge.layer?.cornerRadius = 6
        enterBadge.layer?.borderWidth = 1
        enterBadge.layer?.borderColor = number.layer?.borderColor
        addSubview(enterBadge)
        progressText.frame = bounds
        progressText.wantsLayer = true
        progressText.layer?.mask = progressTextMask
        progressTextMask.backgroundColor = NSColor.white.cgColor
        addSubview(progressText)
        for original in [number, title, marker, enterBadge] {
            let white = NSTextField(labelWithString: original.stringValue)
            white.cell = original.cell?.copy() as? NSCell
            white.font = original.font
            white.alignment = original.alignment
            white.textColor = .white
            white.frame = original.frame
            if original === number || original === enterBadge {
                white.wantsLayer = true
                white.layer?.backgroundColor = Self.activeColor.cgColor
                white.layer?.cornerRadius = 6
                white.layer?.borderWidth = 1
                white.layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
                if original === number { progressNumber = white }
                if original === enterBadge { whiteEnterBadge = white }
            }
            progressText.addSubview(white)
            if original === marker { whiteMarker = white }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func mouseDown(with event: NSEvent) { onClick?() }

    func update(selected: Bool, current: Bool) {
        layer?.backgroundColor = NSColor(srgbRed: 0.965, green: 0.965, blue: 0.975, alpha: 1).cgColor
        layer?.borderColor = (selected
            ? Self.activeColor
            : NSColor(srgbRed: 0.87, green: 0.87, blue: 0.89, alpha: 1)).cgColor
        layer?.borderWidth = 1
        marker.isHidden = !current
        whiteMarker?.isHidden = !current
        enterBadge.isHidden = !selected || current
        whiteEnterBadge?.isHidden = !selected || current
    }
    func startProgress() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.borderColor = Self.confirmedColor.cgColor
        fill.backgroundColor = Self.confirmedColor.cgColor
        progressNumber?.layer?.backgroundColor = Self.confirmedColor.cgColor
        whiteEnterBadge?.layer?.backgroundColor = Self.confirmedColor.cgColor
        fill.removeAllAnimations()
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        progressTextMask.removeAllAnimations()
        progressTextMask.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressTextMask.bounds = bounds
        progressTextMask.position = CGPoint(x: 0, y: bounds.midY)
        CATransaction.commit()
        let animation = CABasicAnimation(keyPath: "transform.scale.x")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 5
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.beginTime = CACurrentMediaTime()
        fill.add(animation, forKey: "progress")
        progressTextMask.add(animation, forKey: "progress")
    }

    func stopProgress() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAllAnimations()
        fill.bounds = .zero
        progressTextMask.removeAllAnimations()
        progressTextMask.bounds = .zero
        CATransaction.commit()
    }
}
