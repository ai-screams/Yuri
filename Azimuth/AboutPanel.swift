//
//  AboutPanel.swift
//  Azimuth
//
//  표준 About 패널을 띄우되, credits 영역에 홈페이지·이슈·후원 링크를 단다.
//  orderFrontStandardAboutPanel(options:)의 .credits(NSAttributedString)는
//  .link 속성을 클릭 가능한 링크로 그대로 렌더한다 — 커스텀 창 없이 정공법으로 해결.
//

import AppKit

@MainActor
enum AboutPanel {
    private static let links: [(title: String, url: String)] = [
        ("Homepage", "https://ai-screams.github.io/Azimuth/"),
        ("Report an Issue", "https://github.com/ai-screams/Azimuth/issues/new"),
        ("Sponsor", "https://github.com/sponsors/pignuante"),
        ("Buy Me a Coffee", "https://buymeacoffee.com/pignuante")
    ]

    /// 표준 About 패널을 credits 링크와 함께 전면에 띄운다.
    static func present() {
        NSApp.activate(ignoringOtherApps: true) // .accessory 빌드에서도 패널이 뒤에 가려지지 않게.
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    private static func credits() -> NSAttributedString {
        let separator = "   ·   "
        let result = NSMutableAttributedString()
        for (index, link) in links.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: separator, attributes: separatorAttributes))
            }
            if let url = URL(string: link.url) {
                result.append(NSAttributedString(string: link.title, attributes: linkAttributes(url)))
            }
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        return result
    }

    private static var separatorAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor]
    }

    private static func linkAttributes(_ url: URL) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 11), .link: url]
    }
}
