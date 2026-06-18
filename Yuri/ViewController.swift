//
//  ViewController.swift
//  Yuri
//
//  Created by hanyul on 3/31/26.
//

import Cocoa

final class ViewController: NSViewController {
    private enum Layout {
        static let windowSize = NSSize(width: 560, height: 420)
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let sectionContentSpacing: CGFloat = 8
        static let sectionPadding: CGFloat = 16
        static let sectionCornerRadius: CGFloat = 10
        static let sectionBorderWidth: CGFloat = 1
        static let minSectionWidth: CGFloat = 512
        static let titleFontSize: CGFloat = 22
        static let sectionTitleFontSize: CGFloat = 15
        static let statusFontSize: CGFloat = 13
    }

    private let titleLabel = NSTextField(labelWithString: "Yuri Settings")
    private let subtitleLabel = NSTextField(
        wrappingLabelWithString: "Development shell for Yuri's menu bar workflow and permissions."
    )

    private let permissionsTitleLabel = NSTextField(labelWithString: "Permissions")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var actionButton = makeActionButton()

    private let shortcutsTitleLabel = NSTextField(labelWithString: "Shortcuts")
    private let shortcutsBodyLabel = NSTextField(
        wrappingLabelWithString: "Next step: register global shortcuts and expose Standard / Vim presets."
    )

    private let behaviorTitleLabel = NSTextField(labelWithString: "Behavior")
    private let behaviorBodyLabel = NSTextField(
        wrappingLabelWithString:
        "Planned: Dock visibility, menu bar presentation, and launch behavior will become user-configurable."
    )

    private lazy var permissionsSection = makeSection(
        titleLabel: permissionsTitleLabel,
        bodyViews: [statusLabel, detailLabel, actionButton]
    )
    private lazy var shortcutsSection = makeSection(
        titleLabel: shortcutsTitleLabel,
        bodyViews: [shortcutsBodyLabel]
    )
    private lazy var behaviorSection = makeSection(
        titleLabel: behaviorTitleLabel,
        bodyViews: [behaviorBodyLabel]
    )
    private lazy var contentStackView = makeContentStackView()

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Layout.windowSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        updatePermissionUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePermissionUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        _ = AccessibilityPermissionService.requestPrompt()

        guard AccessibilityPermissionService.openSystemSettings() else {
            NSSound.beep()
            return
        }
    }

    @objc private func handleDidBecomeActive(_ notification: Notification) {
        updatePermissionUI()
    }

    private func configureView() {
        titleLabel.font = .systemFont(ofSize: Layout.titleFontSize, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0

        permissionsTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)

        statusLabel.font = .systemFont(ofSize: Layout.statusFontSize, weight: .medium)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0

        shortcutsTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)
        shortcutsBodyLabel.textColor = .secondaryLabelColor
        shortcutsBodyLabel.maximumNumberOfLines = 0

        behaviorTitleLabel.font = .systemFont(ofSize: Layout.sectionTitleFontSize, weight: .semibold)
        behaviorBodyLabel.textColor = .secondaryLabelColor
        behaviorBodyLabel.maximumNumberOfLines = 0

        view.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.contentInset),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.contentInset),
            contentStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: Layout.contentInset),
            contentStackView.bottomAnchor.constraint(
                lessThanOrEqualTo: view.bottomAnchor,
                constant: -Layout.contentInset
            )
        ])
    }

    private func updatePermissionUI() {
        let status = AccessibilityPermissionService.currentStatus()

        statusLabel.stringValue = status.settingsStatusText
        statusLabel.textColor = status.isTrusted ? .systemGreen : .systemOrange
        detailLabel.stringValue = status.settingsDetailText
        actionButton.isHidden = status.isTrusted
    }

    private func makeActionButton() -> NSButton {
        let button = NSButton(
            title: "Open Accessibility Settings…",
            target: self,
            action: #selector(openAccessibilitySettings(_:))
        )
        button.bezelStyle = .rounded
        return button
    }

    private func makeContentStackView() -> NSStackView {
        let stackView = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            permissionsSection,
            shortcutsSection,
            behaviorSection
        ])
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Layout.sectionSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    private func makeSection(titleLabel: NSTextField, bodyViews: [NSView]) -> NSBox {
        let stackView = NSStackView(views: [titleLabel] + bodyViews)
        stackView.alignment = .leading
        stackView.orientation = .vertical
        stackView.spacing = Layout.sectionContentSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(
            top: Layout.sectionPadding,
            left: Layout.sectionPadding,
            bottom: Layout.sectionPadding,
            right: Layout.sectionPadding
        )

        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.cornerRadius = Layout.sectionCornerRadius
        box.borderWidth = Layout.sectionBorderWidth
        box.borderColor = .separatorColor
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stackView)

        if let contentView = box.contentView {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                box.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.minSectionWidth)
            ])
        }

        return box
    }
}
