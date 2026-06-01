import AppKit

final class RoundedPathInputView: NSView {
    let textField = NSTextField()
    private var isFocused = false
    private var isError = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.cell?.usesSingleLineMode = true
        textField.cell?.lineBreakMode = .byTruncatingMiddle
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 22)
        ])

        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(textField)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        updateStyle()
    }

    func setError(_ error: Bool) {
        isError = error
        updateStyle()
    }

    private func updateStyle() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
        layer?.borderWidth = isFocused || isError ? 1.5 : 1

        if isError {
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
        } else if isFocused {
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
        } else {
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.8).cgColor
        }
    }
}

final class PathWindowController: NSWindowController, NSTextFieldDelegate {
    private let pathInput: RoundedPathInputView
    private var pathField: NSTextField { pathInput.textField }
    private let statusLabel = NSTextField(labelWithString: "")

    init() {
        let input = RoundedPathInputView()
        self.pathInput = input

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 104))
        let pathField = input.textField

        pathField.placeholderString = "Paste a file or folder path"
        input.translatesAutoresizingMaskIntoConstraints = false

        let openButton = NSButton(title: "Open", target: nil, action: #selector(openPath))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .large
        openButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        openButton.keyEquivalent = "\r"
        openButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.maximumNumberOfLines = 1
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(input)
        contentView.addSubview(openButton)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            input.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            input.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            input.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: -12),
            input.heightAnchor.constraint(equalToConstant: 32),

            openButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            openButton.centerYAnchor.constraint(equalTo: input.centerYAnchor),
            openButton.widthAnchor.constraint(equalToConstant: 74),
            openButton.heightAnchor.constraint(equalToConstant: 32),

            statusLabel.leadingAnchor.constraint(equalTo: input.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: openButton.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: input.bottomAnchor, constant: 11)
        ])

        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Paths"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        pathField.delegate = self
        pathField.target = self
        pathField.action = #selector(openPath)
        openButton.target = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(pathField)
    }

    @objc private func openPath() {
        guard let url = resolvedFileURL(from: pathField.stringValue) else {
            showStatus("Paste a valid path.", isError: true)
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            showStatus("Not found: \(url.path)", isError: true)
            NSSound.beep()
            return
        }

        if isDirectory.boolValue {
            NSWorkspace.shared.open(url)
            showStatus("Opened folder: \(url.path)")
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            showStatus("Revealed file: \(url.path)")
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        pathInput.setError(isError)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        pathInput.setFocused(true)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        pathInput.setFocused(false)
    }

    func controlTextDidChange(_ obj: Notification) {
        pathInput.setError(false)
    }

    private func resolvedFileURL(from input: String) -> URL? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let fileURL = urlFromFileScheme(raw) {
            return fileURL.standardizedFileURL
        }

        for candidate in pathCandidates(from: raw) {
            let expanded = (candidate as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded).standardizedFileURL
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        let fallback = (stripMatchingQuotes(raw) as NSString).expandingTildeInPath
        return URL(fileURLWithPath: fallback).standardizedFileURL
    }

    private func urlFromFileScheme(_ input: String) -> URL? {
        guard let url = URL(string: stripMatchingQuotes(input)), url.isFileURL else {
            return nil
        }
        return url
    }

    private func pathCandidates(from input: String) -> [String] {
        let unquoted = stripMatchingQuotes(input)
        let unescaped = unescapeBackslashPath(unquoted)
        return unescaped == unquoted ? [unquoted] : [unquoted, unescaped]
    }

    private func stripMatchingQuotes(_ input: String) -> String {
        guard input.count >= 2 else { return input }
        let first = input.first
        let last = input.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(input.dropFirst().dropLast())
        }
        return input
    }

    private func unescapeBackslashPath(_ input: String) -> String {
        var output = ""
        var isEscaping = false

        for character in input {
            if isEscaping {
                output.append(character)
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                output.append(character)
            }
        }

        if isEscaping {
            output.append("\\")
        }

        return output
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: PathWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        NSApplication.shared.setActivationPolicy(.regular)

        let controller = PathWindowController()
        windowController = controller
        controller.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Paths",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }
}

@main
struct PathsApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
