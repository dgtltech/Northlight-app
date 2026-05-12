import AppKit

@MainActor
final class ZoomPopoverViewController: NSViewController, NSTextFieldDelegate {

    var onZoomChanged: ((CGFloat) -> Void)?

    private let slider = NSSlider()
    private let textField = NSTextField()
    private let presets: [Int] = [50, 100, 150, 200]

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 78))

        slider.minValue = Double(ZoomController.minFactor * 100)
        slider.maxValue = Double(ZoomController.maxFactor * 100)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(slider)

        let presetStack = NSStackView()
        presetStack.orientation = .horizontal
        presetStack.spacing = 4
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        for value in presets {
            let button = NSButton(title: "\(value)", target: self, action: #selector(presetClicked(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            button.tag = value
            presetStack.addArrangedSubview(button)
        }
        container.addSubview(presetStack)

        textField.alignment = .right
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.target = self
        textField.action = #selector(textFieldCommitted(_:))
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)

        let percentLabel = NSTextField(labelWithString: "%")
        percentLabel.font = NSFont.systemFont(ofSize: 12)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(percentLabel)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),

            presetStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            presetStack.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 12),

            textField.centerYAnchor.constraint(equalTo: presetStack.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: percentLabel.leadingAnchor, constant: -2),
            textField.widthAnchor.constraint(equalToConstant: 56),

            percentLabel.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            percentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        self.view = container
    }

    func setMagnification(_ value: CGFloat) {
        let percent = Int(round(value * 100))
        slider.doubleValue = Double(percent)
        textField.stringValue = "\(percent)"
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let percent = Int(round(sender.doubleValue))
        textField.stringValue = "\(percent)"
        onZoomChanged?(CGFloat(percent) / 100)
    }

    @objc private func presetClicked(_ sender: NSButton) {
        let percent = sender.tag
        slider.doubleValue = Double(percent)
        textField.stringValue = "\(percent)"
        onZoomChanged?(CGFloat(percent) / 100)
    }

    @objc private func textFieldCommitted(_ sender: NSTextField) {
        applyTextField()
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        applyTextField()
        return true
    }

    private func applyTextField() {
        let cleaned = textField.stringValue.trimmingCharacters(in: CharacterSet(charactersIn: "% "))
        guard let value = Int(cleaned) else {
            textField.stringValue = "\(Int(slider.doubleValue))"
            return
        }
        let clamped = max(Int(slider.minValue), min(Int(slider.maxValue), value))
        slider.doubleValue = Double(clamped)
        textField.stringValue = "\(clamped)"
        onZoomChanged?(CGFloat(clamped) / 100)
    }
}
