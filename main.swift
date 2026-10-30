import AppKit
import CoreText

private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

private let bg = rgb(18, 18, 20)
private let fieldBg = rgb(28, 28, 32)
private let ink = rgb(235, 235, 235)
private let muted = rgb(158, 158, 158)
private let green = rgb(92, 181, 86)
private let gray = rgb(141, 143, 147)
private let danger = rgb(202, 60, 63)

private func registerFonts() {
    guard let resource = Bundle.main.resourceURL else { return }
    let url = resource.appendingPathComponent("Monocraft.ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

private func pixelFont(size: CGFloat, heavy: Bool) -> NSFont {
    NSFont(name: "Monocraft", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: heavy ? .semibold : .regular)
}

final class PixelLabel: NSTextField {
    override func draw(_ dirtyRect: NSRect) {
        crisp(NSGraphicsContext.current)
        super.draw(dirtyRect)
    }
}

private func crisp(_ context: NSGraphicsContext?) {
    guard let ctx = context?.cgContext else { return }
    ctx.setShouldAntialias(false)
    ctx.setAllowsFontSmoothing(false)
    ctx.setShouldSmoothFonts(false)
    ctx.interpolationQuality = .none
}

final class PasteFieldEditor: NSTextView {
    override func paste(_ sender: Any?) {
        let raw = NSPasteboard.general.string(forType: .string) ?? ""
        let clean = raw
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        insertText(clean, replacementRange: selectedRange())
    }
}

final class FixedField: NSTextField {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

final class PixelText: NSView {
    let field = FixedField(frame: .zero)

    override var isFlipped: Bool { true }

    init(placeholder: String) {
        super.init(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = fieldBg
        field.textColor = ink
        field.font = pixelFont(size: 16, heavy: false)
        field.focusRingType = .none
        field.autoresizingMask = []
        field.translatesAutoresizingMaskIntoConstraints = true
        if let cell = field.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
            cell.lineBreakMode = .byClipping
        }
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: pixelFont(size: 16, heavy: false),
                .foregroundColor: NSColor(srgbRed: 0.45, green: 0.45, blue: 0.48, alpha: 1),
            ]
        )
        addSubview(field)
        autoresizingMask = []
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        field.frame = bounds.insetBy(dx: 3, dy: 3)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        field.frame = bounds.insetBy(dx: 3, dy: 3)
    }

    override func draw(_ dirtyRect: NSRect) {
        crisp(NSGraphicsContext.current)
        muted.setFill()
        bounds.fill()
    }

    var text: String {
        get { field.stringValue }
        set { field.stringValue = newValue }
    }
}

final class PixelButton: NSView {
    var title: String
    var fill: NSColor
    var onClick: (() -> Void)?
    var isEnabled = true { didSet { needsDisplay = true } }
    private var pressed = false

    init(title: String, fill: NSColor) {
        self.title = title
        self.fill = fill
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        crisp(NSGraphicsContext.current)
        NSColor.black.setFill()
        bounds.fill()
        let inset: CGFloat = pressed ? 5 : 3
        let color = isEnabled ? fill : fill.withAlphaComponent(0.45)
        color.setFill()
        bounds.insetBy(dx: inset, dy: inset).fill()
        let font = pixelFont(size: 16, heavy: true)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let size = (title as NSString).size(withAttributes: attrs)
        let rect = NSRect(
            x: floor((bounds.width - size.width) / 2),
            y: floor((bounds.height - size.height) / 2) - 1,
            width: ceil(size.width),
            height: ceil(size.height)
        )
        (title as NSString).draw(in: rect, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        pressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        let fire = pressed && inside && isEnabled
        pressed = false
        needsDisplay = true
        if fire { onClick?() }
    }
}

final class SecretRow: NSView {
    let name = PixelText(placeholder: "Имя секрета")
    let value = PixelText(placeholder: "значение")
    let remove = PixelButton(title: "x", fill: gray)
    var onRemove: (() -> Void)?
    var showRemove = false

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        autoresizingMask = []
        clipsToBounds = true
        name.autoresizingMask = []
        value.autoresizingMask = []
        remove.autoresizingMask = []
        remove.onClick = { [weak self] in self?.onRemove?() }
        addSubview(name)
        addSubview(value)
        addSubview(remove)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        placeFields()
    }

    func placeFields() {
        let cols = columnFrames(width: bounds.width, showRemove: showRemove)
        name.frame = NSRect(x: cols.name.minX, y: 0, width: cols.name.width, height: bounds.height)
        value.frame = NSRect(x: cols.value.minX, y: 0, width: cols.value.width, height: bounds.height)
        if let box = cols.remove {
            remove.isHidden = false
            remove.frame = NSRect(x: box.minX, y: 0, width: box.width, height: bounds.height)
        } else {
            remove.isHidden = true
        }
    }
}

private struct ColumnFrames {
    var name: NSRect
    var value: NSRect
    var remove: NSRect?
}

private func columnFrames(width: CGFloat, showRemove: Bool) -> ColumnFrames {
    let gap: CGFloat = 8
    let removeWidth: CGFloat = showRemove ? 36 : 0
    let tail = showRemove ? gap + removeWidth : 0
    let fields = max(0, width - tail - gap)
    let column = floor(fields / 2)
    return ColumnFrames(
        name: NSRect(x: 0, y: 0, width: column, height: 0),
        value: NSRect(x: column + gap, y: 0, width: column, height: 0),
        remove: showRemove ? NSRect(x: width - removeWidth, y: 0, width: removeWidth, height: 0) : nil
    )
}

final class RowList: NSView {
    override var isFlipped: Bool { true }
    var rows: [SecretRow] = []
    private var placing = false

    override func layout() {
        super.layout()
        placeRows()
    }

    func placeRows() {
        guard !placing else { return }
        placing = true
        defer { placing = false }
        let showRemove = rows.count > 1
        var y: CGFloat = 0
        let height: CGFloat = 40
        let gap: CGFloat = 8
        let width = bounds.width
        for row in rows {
            row.showRemove = showRemove
            row.autoresizingMask = []
            row.frame = NSRect(x: 0, y: y, width: width, height: height)
            row.placeFields()
            y += height + gap
        }
        let total = max(height, y > 0 ? y - gap : height)
        if abs(frame.height - total) > 0.5 || abs(frame.width - width) > 0.5 {
            setFrameSize(NSSize(width: width, height: total))
        }
    }
}

final class RootView: NSView {
    let titleLabel = PixelLabel(labelWithString: "Добавьте секрет")
    let nameHeader = PixelLabel(labelWithString: "Имя")
    let valueHeader = PixelLabel(labelWithString: "Значение")
    let scroll = NSScrollView()
    let list = RowList()
    let addButton = PixelButton(title: "Добавить", fill: gray)
    let saveButton = PixelButton(title: "Сохранить", fill: green)
    let status = PixelLabel(labelWithString: "Готово к работе.")
    private var saving = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false

        style(titleLabel, size: 24, heavy: true, color: green)
        style(nameHeader, size: 16, heavy: true, color: muted)
        style(valueHeader, size: 16, heavy: true, color: muted)
        style(status, size: 16, heavy: false, color: muted)

        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.autoresizingMask = []
        scroll.documentView = list
        list.autoresizingMask = []

        addButton.onClick = { [weak self] in self?.addRow(focus: true) }
        saveButton.onClick = { [weak self] in self?.save() }
        addButton.autoresizingMask = []
        saveButton.autoresizingMask = []

        addSubview(titleLabel)
        addSubview(nameHeader)
        addSubview(valueHeader)
        addSubview(scroll)
        addSubview(addButton)
        addSubview(saveButton)
        addSubview(status)
        addRow(focus: false)
    }

    required init?(coder: NSCoder) { nil }

    private func style(_ label: NSTextField, size: CGFloat, heavy: Bool, color: NSColor) {
        label.font = pixelFont(size: size, heavy: heavy)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.autoresizingMask = []
    }

    override func draw(_ dirtyRect: NSRect) {
        bg.setFill()
        dirtyRect.fill()
    }

    override func layout() {
        super.layout()
        let pad: CGFloat = 22
        let width = bounds.width - pad * 2
        titleLabel.frame = NSRect(x: pad, y: 12, width: width, height: 36)

        let showRemove = list.rows.count > 1
        let cols = columnFrames(width: width, showRemove: showRemove)
        nameHeader.frame = NSRect(x: pad + cols.name.minX, y: 54, width: cols.name.width, height: 18)
        valueHeader.frame = NSRect(x: pad + cols.value.minX, y: 54, width: cols.value.width, height: 18)

        let scrollTop: CGFloat = 78
        let buttonH: CGFloat = 40
        let statusH: CGFloat = 22
        let bottom: CGFloat = 14
        let compactButtons = scrollTop + 96 + 14
        let buttonY = max(compactButtons, bounds.height - bottom - statusH - 10 - buttonH)
        scroll.frame = NSRect(x: pad, y: scrollTop, width: width, height: buttonY - 14 - scrollTop)
        let contentWidth = max(1, scroll.contentSize.width)
        if abs(list.frame.width - contentWidth) > 0.5 {
            list.setFrameSize(NSSize(width: contentWidth, height: max(list.frame.height, 40)))
        }
        list.placeRows()

        let addWidth = buttonWidth("Добавить")
        let saveWidth = buttonWidth("Сохранить")
        addButton.frame = NSRect(x: pad, y: buttonY, width: addWidth, height: buttonH)
        saveButton.frame = NSRect(x: pad + addWidth + 10, y: buttonY, width: saveWidth, height: buttonH)
        status.frame = NSRect(x: pad, y: buttonY + buttonH + 10, width: width, height: statusH)
    }

    private func buttonWidth(_ title: String) -> CGFloat {
        let size = (title as NSString).size(withAttributes: [.font: pixelFont(size: 16, heavy: true)])
        return max(132, ceil(size.width) + 36)
    }

    private func addRow(focus: Bool) {
        let row = SecretRow()
        row.onRemove = { [weak self, weak row] in
            guard let self, let row else { return }
            self.remove(row)
        }
        list.rows.append(row)
        list.addSubview(row)
        list.placeRows()
        needsLayout = true
        layoutSubtreeIfNeeded()
        if focus {
            row.scrollToVisible(row.bounds)
            window?.makeFirstResponder(row.name.field)
        }
    }

    private func remove(_ row: SecretRow) {
        guard list.rows.count > 1, let index = list.rows.firstIndex(where: { $0 === row }) else { return }
        row.removeFromSuperview()
        list.rows.remove(at: index)
        list.placeRows()
        needsLayout = true
    }

    private func setStatus(_ text: String, color: NSColor) {
        status.stringValue = text
        status.textColor = color
        status.toolTip = text
    }

    private func setBusy(_ busy: Bool) {
        saving = busy
        addButton.isEnabled = !busy
        saveButton.isEnabled = !busy
        for row in list.rows {
            row.name.field.isEnabled = !busy
            row.value.field.isEnabled = !busy
            row.remove.isEnabled = !busy
        }
    }

    private func save() {
        guard !saving else { return }
        switch collect() {
        case .empty:
            setStatus("Нечего сохранять.", color: danger)
        case .invalid(let message):
            setStatus(message, color: danger)
        case .ready(let drafts):
            setBusy(true)
            setStatus("Сохраняю…", color: muted)
            let payload = drafts.map { ["name": $0.name, "value": $0.value] }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Self.runScript(payload)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.setBusy(false)
                    switch result {
                    case .success:
                        for row in self.list.rows {
                            row.value.text = ""
                        }
                        let names = drafts.map(\.name).joined(separator: ", ")
                        self.setStatus("Сохранено: \(names).", color: green)
                    case .failure(let message):
                        self.setStatus(message, color: danger)
                    }
                }
            }
        }
    }

    private struct Draft {
        var name: String
        var value: String
    }

    private enum Collected {
        case empty
        case invalid(String)
        case ready([Draft])
    }

    private func collect() -> Collected {
        var drafts: [Draft] = []
        for row in list.rows {
            let name = row.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = row.value.text
            if name.isEmpty && value.isEmpty { continue }
            if name.isEmpty || value.isEmpty {
                return .invalid("Заполни и имя, и значение.")
            }
            let ok = name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
            if !ok {
                return .invalid("Имя должно быть как JIRA_TOKEN.")
            }
            if drafts.contains(where: { $0.name == name }) {
                return .invalid("Имя \(name) повторяется.")
            }
            drafts.append(Draft(name: name, value: value))
        }
        if drafts.isEmpty { return .empty }
        return .ready(drafts)
    }

    private enum ScriptResult {
        case success
        case failure(String)
    }

    private static func runScript(_ items: [[String: String]]) -> ScriptResult {
        guard let script = Bundle.main.url(forResource: "save-secrets", withExtension: "sh") else {
            return .failure("Не найден save-secrets.sh")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items) else {
            return .failure("Не собрал данные для скрипта.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return .failure("Не запустил скрипт.")
        }
        input.fileHandleForWriting.write(data)
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()
        let errText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var message = errText.trimmingCharacters(in: .whitespacesAndNewlines)
        for item in items {
            let value = item["value"] ?? ""
            let name = item["name"] ?? "NAME"
            if !value.isEmpty {
                message = message.replacingOccurrences(of: value, with: "$\(name)")
            }
        }
        if process.terminationStatus == 0 {
            return .success
        }
        if message.isEmpty {
            message = "Не получилось записать в Связку ключей."
        }
        return .failure(message)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let fieldEditor: PasteFieldEditor = {
        let editor = PasteFieldEditor()
        editor.isFieldEditor = true
        editor.insertionPointColor = .white
        return editor
    }()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 560, height: 280),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    let root = RootView(frame: NSRect(x: 0, y: 0, width: 560, height: 280))

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeEditMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFonts()
        NSApp.appearance = NSAppearance(named: .darkAqua)
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "Секреты"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.backgroundColor = bg
        window.isMovableByWindowBackground = true
        window.delegate = self
        root.autoresizingMask = [.width, .height]
        window.contentView = root
        window.minSize = NSSize(width: 520, height: 280)
        window.setContentSize(NSSize(width: 560, height: 280))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(
            forName: NSText.didBeginEditingNotification,
            object: nil,
            queue: .main
        ) { note in
            (note.object as? NSTextView)?.insertionPointColor = .white
        }
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        guard let field = client as? NSTextField else { return nil }
        fieldEditor.font = field.font
        fieldEditor.textColor = field.textColor ?? ink
        fieldEditor.backgroundColor = field.backgroundColor ?? fieldBg
        fieldEditor.drawsBackground = true
        fieldEditor.insertionPointColor = .white
        return fieldEditor
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private func makeEditMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem()
    main.addItem(appItem)
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "Закрыть", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appItem.submenu = appMenu

    let editItem = NSMenuItem()
    main.addItem(editItem)
    let edit = NSMenu(title: "Правка")
    let paste = NSMenuItem(title: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    let copy = NSMenuItem(title: "Скопировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    let cut = NSMenuItem(title: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    let selectAll = NSMenuItem(title: "Выбрать всё", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    for item in [cut, copy, paste, selectAll] {
        item.target = nil
        edit.addItem(item)
    }
    editItem.submenu = edit
    return main
}

private let appDelegate = AppDelegate()

@main
struct SecretPadMain {
    static func main() {
        registerFonts()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = appDelegate
        app.run()
    }
}
