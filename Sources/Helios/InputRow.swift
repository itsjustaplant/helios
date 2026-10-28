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
        layer?.backgroundColor = NSColor.white.withAlphaComponent(selected ? 0.15 : 0.06).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(selected ? 0.45 : 0.14).cgColor
        marker.isHidden = !current
    }
    func startProgress() {
        fill.removeAllAnimations()
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = 0
        animation.toValue = bounds.width
        animation.duration = 1
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        fill.add(animation, forKey: "progress")
    }
    func stopProgress() {
        fill.removeAllAnimations()
        fill.frame = .zero
    }
}
