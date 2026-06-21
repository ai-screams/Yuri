//
//  ShortcutsSectionView.swift
//  Yuri
//
//  Shortcuts 설정 섹션 본문: 프리셋 선택 + 명령별 단축키 레코더 목록 + 충돌/점유 경고.
//

import Cocoa

@MainActor
final class ShortcutsSectionView: NSView {
    private enum Metric {
        static let rowHeight: CGFloat = 26
        static let nameWidth: CGFloat = 150
        static let recorderWidth: CGFloat = 120
        static let resetWidth: CGFloat = 56
        static let listHeight: CGFloat = 220
        static let captionFontSize: CGFloat = 13
        static let rowSpacing: CGFloat = 6
    }

    private let preferencesStore: PreferencesStore
    private let onHotkeysChanged: () -> Void
    private let registrationFailures: () -> Set<String>
    private let setHotkeysSuspended: (Bool) -> Void

    private lazy var presetPopUp = makePresetPopUp()
    private let rowsStack = NSStackView()
    private var rows: [Row] = []

    struct Row {
        let command: WindowCommand
        let recorder: ShortcutRecorderButton
        let resetButton: NSButton
        let warningLabel: NSTextField
    }

    init(
        preferencesStore: PreferencesStore,
        onHotkeysChanged: @escaping () -> Void,
        registrationFailures: @escaping () -> Set<String>,
        setHotkeysSuspended: @escaping (Bool) -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.onHotkeysChanged = onHotkeysChanged
        self.registrationFailures = registrationFailures
        self.setHotkeysSuspended = setHotkeysSuspended
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildLayout()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 실효 바인딩·충돌·등록 실패를 다시 계산해 각 행을 갱신한다.
    func refresh() {
        let overrides = preferencesStore.customShortcuts
        let bindings = BindingResolver.resolve(preset: preferencesStore.activePreset, overrides: overrides)
        let byIdentifier = Dictionary(
            bindings.map { ($0.command.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let conflicts = BindingResolver.conflictingIdentifiers(in: bindings)
        let failures = registrationFailures()

        for row in rows {
            let identifier = row.command.identifier
            if let binding = byIdentifier[identifier] {
                let shortcut = HotkeyShortcut(keyCode: binding.keyCode, modifiers: binding.modifiers)
                row.recorder.setIdleDisplay(shortcut.displayString)
            } else {
                row.recorder.setIdleDisplay("")
            }
            row.resetButton.isEnabled = overrides[identifier] != nil
            apply(warning: warningText(for: identifier, conflicts: conflicts, failures: failures), to: row.warningLabel)
        }
    }

    /// 내부 중복을 시스템 점유보다 우선 표시한다(중복이면 둘 다 등록 실패할 수 있어 메시지가 엇갈리지 않게).
    private func warningText(for identifier: String, conflicts: Set<String>, failures: Set<String>) -> String {
        if conflicts.contains(identifier) { return "Duplicate" }
        if failures.contains(identifier) { return "In use by system" }
        return ""
    }

    private func apply(warning: String, to label: NSTextField) {
        label.stringValue = warning
        label.toolTip = warning.isEmpty ? nil : "\(warning) — this shortcut won't trigger this command."
        label.isHidden = warning.isEmpty
    }
}

private extension ShortcutsSectionView {
    func buildLayout() {
        configureRowsStack()
        let scroll = makeScrollView()
        let hint = NSTextField(
            wrappingLabelWithString: "Click a shortcut to record a new key combo. Esc cancels."
        )
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: Metric.captionFontSize)
        hint.maximumNumberOfLines = 0

        let outer = NSStackView(views: [makeHeader(), hint, scroll])
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = Metric.rowSpacing
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)

        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outer.topAnchor.constraint(equalTo: topAnchor),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: outer.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: Metric.listHeight)
        ])
    }

    func makeHeader() -> NSStackView {
        let caption = NSTextField(labelWithString: "Keymap preset")
        caption.font = .systemFont(ofSize: Metric.captionFontSize, weight: .medium)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let resetAll = NSButton(title: "Reset All", target: self, action: #selector(resetAll))
        resetAll.bezelStyle = .rounded

        let header = NSStackView(views: [caption, presetPopUp, spacer, resetAll])
        header.orientation = .horizontal
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    func makeScrollView() -> NSScrollView {
        // documentView는 flipped여야 행이 위에서 아래로(Maximize가 맨 위) 쌓이고 스크롤 시작이 상단이 된다.
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rowsStack)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = document
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rowsStack.topAnchor.constraint(equalTo: document.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])
        return scroll
    }

    func configureRowsStack() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = Metric.rowSpacing
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        for command in WindowCommand.menuCommands {
            rows.append(makeRow(for: command))
        }
    }

    func makeRow(for command: WindowCommand) -> Row {
        let name = NSTextField(labelWithString: command.displayName)
        name.lineBreakMode = .byTruncatingTail

        let warning = NSTextField(labelWithString: "")
        warning.textColor = .systemOrange
        warning.font = .systemFont(ofSize: Metric.captionFontSize)
        warning.lineBreakMode = .byTruncatingTail
        warning.isHidden = true
        // 경고는 행 끝에서 남는 공간을 채우되, 좁으면 잘리게 해 고정폭 컨트롤을 밀어내지 않는다.
        warning.setContentHuggingPriority(.defaultLow, for: .horizontal)
        warning.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let recorder = ShortcutRecorderButton()
        recorder.onCapture = { [weak self] shortcut in self?.capture(shortcut, for: command) }
        // 녹화 중에는 전역 핫키를 일시 정지해, 녹화하려는 조합이 백그라운드 창을 조작하지 않게 한다.
        recorder.onRecordingStateChanged = { [weak self] recording in self?.setHotkeysSuspended(recording) }

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetRow(_:)))
        reset.bezelStyle = .rounded

        let container = NSStackView(views: [name, recorder, reset, warning])
        container.orientation = .horizontal
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.addArrangedSubview(container)

        NSLayoutConstraint.activate([
            name.widthAnchor.constraint(equalToConstant: Metric.nameWidth),
            recorder.widthAnchor.constraint(equalToConstant: Metric.recorderWidth),
            reset.widthAnchor.constraint(equalToConstant: Metric.resetWidth),
            container.heightAnchor.constraint(equalToConstant: Metric.rowHeight),
            container.widthAnchor.constraint(equalTo: rowsStack.widthAnchor)
        ])
        return Row(command: command, recorder: recorder, resetButton: reset, warningLabel: warning)
    }

    func makePresetPopUp() -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for preset in HotkeyPreset.allCases {
            popUp.addItem(withTitle: preset.displayName)
            popUp.lastItem?.representedObject = preset
        }
        if let index = HotkeyPreset.allCases.firstIndex(of: preferencesStore.activePreset) {
            popUp.selectItem(at: index)
        }
        popUp.target = self
        popUp.action = #selector(presetChanged(_:))
        return popUp
    }

    func capture(_ shortcut: HotkeyShortcut, for command: WindowCommand) {
        preferencesStore.setShortcut(shortcut, forCommand: command.identifier)
        onHotkeysChanged()
        refresh()
    }

    @objc func presetChanged(_ sender: NSPopUpButton) {
        guard let preset = sender.selectedItem?.representedObject as? HotkeyPreset else { return }
        preferencesStore.activePreset = preset
        onHotkeysChanged()
        refresh()
    }

    @objc func resetRow(_ sender: NSButton) {
        guard let row = rows.first(where: { $0.resetButton == sender }) else { return }
        preferencesStore.clearShortcut(forCommand: row.command.identifier)
        onHotkeysChanged()
        refresh()
    }

    @objc func resetAll() {
        preferencesStore.clearAllShortcuts()
        onHotkeysChanged()
        refresh()
    }
}

/// 위에서 아래로 콘텐츠를 쌓기 위한 flipped 컨테이너(NSScrollView documentView용).
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
