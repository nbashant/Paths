import AppKit
import Foundation
import UniformTypeIdentifiers

private let maxVisibleResults = 7
private let metadataReadLimit = 400

final class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct FileSearchResult: Equatable {
    enum Source {
        case exactPath
        case spotlight
    }

    let url: URL
    let displayName: String
    let path: String
    let modifiedDate: Date?
    let isDirectory: Bool
    let source: Source
}

final class FileIconCache {
    private var icons: [String: NSImage] = [:]

    func icon(for result: FileSearchResult) -> NSImage {
        let key: String
        if result.isDirectory {
            key = "folder"
        } else {
            let ext = result.url.pathExtension.lowercased()
            key = ext.isEmpty ? "file" : "ext:\(ext)"
        }

        if let icon = icons[key]?.copy() as? NSImage {
            return icon
        }

        let icon: NSImage
        if result.isDirectory {
            icon = NSWorkspace.shared.icon(for: .folder)
        } else if let type = UTType(filenameExtension: result.url.pathExtension) {
            icon = NSWorkspace.shared.icon(for: type)
        } else {
            icon = NSWorkspace.shared.icon(for: .data)
        }

        icon.size = NSSize(width: 32, height: 32)
        icons[key] = icon
        return icon.copy() as? NSImage ?? icon
    }
}

final class GlassPanelView: NSView {
    let contentView = NSView()
    private let backgroundView: NSView
    private let washView = NSView()

    override init(frame frameRect: NSRect) {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: .zero)
            glass.cornerRadius = 21
            glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.08)
            glass.clipsToBounds = true
            backgroundView = glass
        } else {
            let effect = NSVisualEffectView(frame: .zero)
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 21
            effect.layer?.cornerCurve = .continuous
            effect.layer?.masksToBounds = true
            backgroundView = effect
        }

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 22
        layer?.shadowOffset = NSSize(width: 0, height: -10)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        washView.translatesAutoresizingMaskIntoConstraints = false
        washView.wantsLayer = true
        washView.layer?.cornerRadius = 21
        washView.layer?.cornerCurve = .continuous
        washView.layer?.masksToBounds = true
        washView.layer?.borderWidth = 1
        washView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        washView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.30).cgColor

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(backgroundView)
        addSubview(washView)
        addSubview(contentView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            washView.leadingAnchor.constraint(equalTo: leadingAnchor),
            washView.trailingAnchor.constraint(equalTo: trailingAnchor),
            washView.topAnchor.constraint(equalTo: topAnchor),
            washView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SearchInputView: NSView {
    let textField = NSTextField()
    private let iconView = NSImageView()
    private var isFocused = false
    private var isError = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        iconView.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Search"
        )
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        textField.placeholderString = "Paste a path or search files"
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        textField.cell?.usesSingleLineMode = true
        textField.cell?.lineBreakMode = .byTruncatingMiddle
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textField)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),

            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 11),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 28)
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
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = isError ? 1 : 0

        if isError {
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.75).cgColor
        } else {
            layer?.borderColor = NSColor.clear.cgColor
        }

        iconView.contentTintColor = isFocused ? .labelColor : .secondaryLabelColor
    }
}

final class ResultRowView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let index: Int
    private let selectHandler: (Int) -> Void
    private let openHandler: (Int) -> Void

    init(
        result: FileSearchResult,
        icon: NSImage,
        dateText: String,
        index: Int,
        isSelected: Bool,
        selectHandler: @escaping (Int) -> Void,
        openHandler: @escaping (Int) -> Void
    ) {
        self.index = index
        self.selectHandler = selectHandler
        self.openHandler = openHandler
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.cornerCurve = .continuous

        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.stringValue = result.displayName
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        pathLabel.stringValue = result.path
        pathLabel.font = NSFont.systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.maximumNumberOfLines = 1
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.stringValue = dateText
        dateLabel.font = NSFont.systemFont(ofSize: 11)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.alignment = .right
        dateLabel.lineBreakMode = .byTruncatingTail
        dateLabel.maximumNumberOfLines = 1
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(pathLabel)
        addSubview(dateLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(equalToConstant: 154),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -12),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3)
        ])

        setSelected(isSelected)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0 else { return nil }

        if bounds.contains(point) {
            return self
        }

        if let superview {
            let localPoint = convert(point, from: superview)
            if bounds.contains(localPoint) {
                return self
            }
        }

        return nil
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            openHandler(index)
        } else {
            selectHandler(index)
        }
    }

    func setSelected(_ selected: Bool) {
        layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            : NSColor.clear.cgColor
    }
}

final class ResultsListView: NSView {
    private let stackView = NSStackView()
    private var rowViews: [ResultRowView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.distribution = .gravityAreas
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        results: [FileSearchResult],
        selectedIndex: Int?,
        iconCache: FileIconCache,
        dateFormatter: DateFormatter,
        selectHandler: @escaping (Int) -> Void,
        openHandler: @escaping (Int) -> Void
    ) {
        rowViews.forEach { row in
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        rowViews.removeAll()

        for (index, result) in results.enumerated() {
            let row = ResultRowView(
                result: result,
                icon: iconCache.icon(for: result),
                dateText: result.modifiedDate.map { dateFormatter.string(from: $0) } ?? "Modified unknown",
                index: index,
                isSelected: selectedIndex == index,
                selectHandler: selectHandler,
                openHandler: openHandler
            )
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 56).isActive = true
            stackView.addArrangedSubview(row)
            rowViews.append(row)
        }
    }

    func setSelectedIndex(_ selectedIndex: Int?) {
        for (index, row) in rowViews.enumerated() {
            row.setSelected(selectedIndex == index)
        }
    }
}

final class PathWindowController: NSWindowController, NSTextFieldDelegate {
    private let panelView = GlassPanelView()
    private let searchInput = SearchInputView()
    private let resultsView = ResultsListView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let iconCache = FileIconCache()
    private let dateFormatter = DateFormatter()
    private var resultsHeightConstraint: NSLayoutConstraint?

    private var searchField: NSTextField { searchInput.textField }
    private var results: [FileSearchResult] = []
    private var selectedIndex: Int?
    private var activeQuery: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []
    private var searchDebounce: DispatchWorkItem?
    private var activeSearchTerm = ""

    init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 78))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.doesRelativeDateFormatting = true

        panelView.translatesAutoresizingMaskIntoConstraints = false
        searchInput.translatesAutoresizingMaskIntoConstraints = false
        resultsView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(panelView)
        panelView.contentView.addSubview(searchInput)
        panelView.contentView.addSubview(resultsView)
        panelView.contentView.addSubview(statusLabel)

        let resultsHeightConstraint = resultsView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: contentView.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            searchInput.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 24),
            searchInput.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -24),
            searchInput.topAnchor.constraint(equalTo: panelView.contentView.topAnchor, constant: 12),
            searchInput.heightAnchor.constraint(equalToConstant: 54),

            resultsView.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 12),
            resultsView.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -12),
            resultsView.topAnchor.constraint(equalTo: searchInput.bottomAnchor, constant: 8),
            resultsHeightConstraint,

            statusLabel.leadingAnchor.constraint(equalTo: searchInput.leadingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: searchInput.trailingAnchor, constant: -4),
            statusLabel.topAnchor.constraint(equalTo: searchInput.bottomAnchor, constant: 7)
        ])

        let window = SpotlightWindow(
            contentRect: contentView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Paths"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        self.resultsHeightConstraint = resultsHeightConstraint
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(openSelectedResult)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancelSearch()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(searchField)
    }

    @objc private func openSelectedResult() {
        let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = resolvedExistingFileURL(from: text) {
            open(url: url)
            return
        }

        if let index = selectedIndex, results.indices.contains(index) {
            open(result: results[index])
        } else if let first = results.first {
            open(result: first)
        } else if !text.isEmpty {
            showStatus("No match found.", isError: true)
            NSSound.beep()
        }
    }

    private func open(result: FileSearchResult) {
        open(url: result.url)
    }

    private func open(url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            showStatus("Not found: \(url.path)", isError: true)
            NSSound.beep()
            return
        }

        if isDirectory.boolValue {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        showStatus("")
    }

    private func selectResult(at index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
        resultsView.setSelectedIndex(index)
    }

    private func moveSelection(delta: Int) {
        guard !results.isEmpty else { return }
        let current = selectedIndex ?? (delta > 0 ? -1 : results.count)
        let next = max(0, min(results.count - 1, current + delta))
        selectResult(at: next)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        searchInput.setFocused(true)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        searchInput.setFocused(false)
    }

    func controlTextDidChange(_ obj: Notification) {
        searchInput.setError(false)
        handleSearchTextChange()
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            openSelectedResult()
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(delta: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(delta: -1)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            clearSearch()
            return true
        default:
            return false
        }
    }

    private func handleSearchTextChange() {
        let rawText = searchField.stringValue
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounce?.cancel()

        if text.isEmpty {
            cancelSearch()
            applyResults([], status: "")
            return
        }

        if let exactResult = exactPathResult(from: text) {
            cancelSearch()
            applyResults([exactResult], status: "")
            return
        }

        if looksLikePath(text) {
            cancelSearch()
            applyResults([], status: "No exact path found.")
            return
        }

        if text.count < 2 {
            cancelSearch()
            applyResults([], status: "")
            return
        }

        applyResults([], status: "Searching...")

        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.startMetadataSearch(for: text)
            }
        }
        searchDebounce = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + .milliseconds(120),
            execute: workItem
        )
    }

    private func clearSearch() {
        if searchField.stringValue.isEmpty {
            window?.close()
        } else {
            searchField.stringValue = ""
            cancelSearch()
            applyResults([], status: "")
        }
    }

    private func startMetadataSearch(for term: String) {
        cancelSearch()
        activeSearchTerm = term

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.predicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, term)
        query.notificationBatchingInterval = 0.1

        let center = NotificationCenter.default
        let finishObserver = center.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self, weak query] _ in
            guard let self, let query, self.activeQuery === query else { return }
            self.finishMetadataSearch(query, term: term)
        }

        let updateObserver = center.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self, weak query] _ in
            guard let self, let query, self.activeQuery === query else { return }
            self.applyMetadataResults(from: query, term: term, stopQuery: false)
        }

        queryObservers = [finishObserver, updateObserver]
        activeQuery = query

        if !query.start() {
            cancelSearch()
            applyResults([], status: "Search unavailable.")
        }
    }

    private func finishMetadataSearch(_ query: NSMetadataQuery, term: String) {
        applyMetadataResults(from: query, term: term, stopQuery: true)
    }

    private func applyMetadataResults(
        from query: NSMetadataQuery,
        term: String,
        stopQuery: Bool
    ) {
        guard term == activeSearchTerm else { return }

        query.disableUpdates()
        let ranked = rankedResults(from: query, term: term)
        if stopQuery {
            cancelSearch()
        } else {
            query.enableUpdates()
        }

        let visible = Array(ranked.prefix(maxVisibleResults))
        let status = visible.isEmpty ? "No results found." : ""
        applyResults(visible, status: status)
    }

    private func rankedResults(from query: NSMetadataQuery, term: String) -> [FileSearchResult] {
        let count = min(query.resultCount, metadataReadLimit)
        guard count > 0 else { return [] }

        var seenPaths = Set<String>()
        var scoredResults: [(result: FileSearchResult, score: Int)] = []

        for index in 0..<count {
            guard
                let item = query.result(at: index) as? NSMetadataItem,
                let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                continue
            }

            guard seenPaths.insert(path).inserted else { continue }

            let name = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String)
                ?? URL(fileURLWithPath: path).lastPathComponent
            if name.hasPrefix(".") && !term.hasPrefix(".") {
                continue
            }

            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }

            let modifiedDate = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date)
                ?? (item.value(forAttribute: NSMetadataItemContentModificationDateKey) as? Date)

            let result = FileSearchResult(
                url: url,
                displayName: name,
                path: path,
                modifiedDate: modifiedDate,
                isDirectory: isDirectory.boolValue,
                source: .spotlight
            )
            scoredResults.append((result, score(result: result, term: term)))
        }

        return scoredResults
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }

                let lhsDate = lhs.result.modifiedDate ?? .distantPast
                let rhsDate = rhs.result.modifiedDate ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }

                return lhs.result.displayName.localizedStandardCompare(rhs.result.displayName) == .orderedAscending
            }
            .map(\.result)
    }

    private func score(result: FileSearchResult, term: String) -> Int {
        let normalizedTerm = term.lowercased()
        let name = result.displayName.lowercased()
        let stem = (result.displayName as NSString).deletingPathExtension.lowercased()
        var score: Int

        if name == normalizedTerm || stem == normalizedTerm {
            score = 0
        } else if name.hasPrefix(normalizedTerm) {
            score = 8
        } else if stem.hasPrefix(normalizedTerm) {
            score = 10
        } else if let range = name.range(of: normalizedTerm) {
            score = 24 + name.distance(from: name.startIndex, to: range.lowerBound)
        } else {
            score = 80
        }

        if result.path.hasPrefix(NSHomeDirectory()) {
            score -= 3
        }

        if result.path.contains("/System/") || result.path.contains("/Library/") {
            score += 8
        }

        if result.path.contains("/node_modules/")
            || result.path.contains("/target/")
            || result.path.contains("/DerivedData/")
            || result.path.contains("/.git/")
        {
            score += 18
        }

        if result.isDirectory {
            score += 1
        }

        return score
    }

    private func cancelSearch() {
        searchDebounce?.cancel()
        searchDebounce = nil

        activeQuery?.stop()
        activeQuery = nil
        activeSearchTerm = ""

        let center = NotificationCenter.default
        queryObservers.forEach { center.removeObserver($0) }
        queryObservers.removeAll()
    }

    private func applyResults(_ newResults: [FileSearchResult], status: String) {
        results = newResults
        selectedIndex = newResults.isEmpty ? nil : 0
        resultsView.update(
            results: newResults,
            selectedIndex: selectedIndex,
            iconCache: iconCache,
            dateFormatter: dateFormatter,
            selectHandler: { [weak self] index in
                self?.selectResult(at: index)
            },
            openHandler: { [weak self] index in
                guard let self, self.results.indices.contains(index) else { return }
                self.open(result: self.results[index])
            }
        )
        let shouldShowStatus = !status.isEmpty && newResults.isEmpty
        showStatus(shouldShowStatus ? status : "", isError: status.hasPrefix("No exact") || status.hasPrefix("Search unavailable"))
        resizeWindowForResults(count: newResults.count, hasStatus: shouldShowStatus)
    }

    private func resizeWindowForResults(count: Int, hasStatus: Bool) {
        let rowHeight = count > 0 ? CGFloat(count) * 60 + 10 : 0
        let statusHeight: CGFloat = hasStatus && count == 0 ? 24 : 0
        let contentHeight = max(78, 78 + rowHeight + statusHeight)
        guard let window else { return }

        resultsHeightConstraint?.constant = rowHeight

        var frame = window.frame
        let heightDelta = contentHeight - frame.height
        frame.origin.y -= heightDelta
        frame.size.height = contentHeight
        frame.size.width = 680
        window.setFrame(frame, display: true, animate: false)
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.isHidden = message.isEmpty
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        searchInput.setError(isError)
    }

    private func exactPathResult(from input: String) -> FileSearchResult? {
        guard let url = resolvedExistingFileURL(from: input) else { return nil }
        return makeResult(url: url, source: .exactPath)
    }

    private func makeResult(url: URL, source: FileSearchResult.Source) -> FileSearchResult {
        let resourceValues = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .isDirectoryKey,
            .localizedNameKey
        ])
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)

        let isDirectory = resourceValues?.isDirectory ?? false
        let displayName = resourceValues?.localizedName ?? url.lastPathComponent
        let modifiedDate = resourceValues?.contentModificationDate
            ?? attributes?[.modificationDate] as? Date

        return FileSearchResult(
            url: url,
            displayName: displayName.isEmpty ? url.path : displayName,
            path: url.path,
            modifiedDate: modifiedDate,
            isDirectory: isDirectory,
            source: source
        )
    }

    private func resolvedExistingFileURL(from input: String) -> URL? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let fileURL = urlFromFileScheme(raw), fileExists(at: fileURL) {
            return fileURL.standardizedFileURL
        }

        for candidate in pathCandidates(from: raw) {
            let expanded = (candidate as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded).standardizedFileURL
            if fileExists(at: url) {
                return url
            }
        }

        return nil
    }

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func looksLikePath(_ input: String) -> Bool {
        input.hasPrefix("/")
            || input.hasPrefix("~/")
            || input.hasPrefix("./")
            || input.hasPrefix("../")
            || input.hasPrefix("file://")
            || input.contains("/")
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
