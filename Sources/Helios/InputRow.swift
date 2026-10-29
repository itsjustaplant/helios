import AppKit

@MainActor
final class InputRow: NSView {
    var onClick: (() -> Void)?
    private let fill = CALayer()
    private let title = NSTextField(labelWithString: "")
    private let marker = NSTextField(labelWithString: "Current")

    init(frame: NSRect, title text: String) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.addSublayer(fill)
        fill.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.48).cgColor
        title.stringValue = text
        title.font = .systemFont(ofSize: 14, weight: .medium)
        title.frame = NSRect(x: 14, y: 12, width: 190, height: 20)
        addSubview(title)
        marker.font = .systemFont(ofSize: 11, weight: .medium)
        marker.textColor = .secondaryLabelColor
        marker.frame = NSRect(x: 230, y: 13, width: 58, height: 18)
        addSubview(marker)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func mouseDown(with event: NSEvent) { onClick?() }

    func update(selected: Bool, current: Bool) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(selected ? 0.12 : 0.055).cgColor
        layer?.borderColor = NSColor.labelColor.withAlphaComponent(selected ? 0.16 : 0.09).cgColor
        layer?.borderWidth = 1
        marker.isHidden = !current
    }
    func startProgress() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAllAnimations()
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        CATransaction.commit()
        let animation = CABasicAnimation(keyPath: "transform.scale.x")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 5
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        fill.add(animation, forKey: "progress")
    }

    func stopProgress() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAllAnimations()
        fill.bounds = .zero
        CATransaction.commit()
    }
}
