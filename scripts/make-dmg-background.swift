#!/usr/bin/env swift
//
// Azimuth DMG 창 배경 생성기 (정공법: AppKit/CoreGraphics 네이티브 렌더)
//
// 출력:  scripts/dmg/background.png      (540×380, 1x)
//        scripts/dmg/background@2x.png   (1080×760, retina)
//
// create-dmg --background background.png 로 연결한다. @2x가 같은 폴더에 있으면
// create-dmg가 retina용 multi-resolution TIFF로 자동 결합한다.
//
// 좌표계: AppKit 기본(좌하단 원점, y가 위로 증가). 아이콘은 create-dmg가
// Finder 좌상단 기준(140,200)/(400,200)으로 배치하므로, 배경의 시각 요소는
// 바닥 기준 y = 380 - finderY 로 환산해 같은 자리에 오게 그린다.

import AppKit

let W: CGFloat = 540
let H: CGFloat = 380

// 브랜드 색 (앱 아이콘의 딥 네이비 계열)
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
let topColor = rgb(34, 51, 90)      // #22335a
let bottomColor = rgb(13, 21, 38)   // #0d1526
let accent = rgb(150, 180, 230)     // 흐린 블루(나침반 침 하이라이트 느낌)

func render(scale s: CGFloat) -> Data {
    let pw = Int(W * s), ph = Int(H * s)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.scaleBy(x: s, y: s) // 이후 좌표는 1x 논리 포인트로 작업

    let full = NSRect(x: 0, y: 0, width: W, height: H)

    // 1) 세로 그라데이션 배경
    let grad = NSGradient(starting: bottomColor, ending: topColor)!
    grad.draw(in: full, angle: 90)

    // 2) 블루프린트 그리드 (아주 옅게)
    NSColor(white: 1, alpha: 0.04).setStroke()
    let grid = NSBezierPath()
    grid.lineWidth = 1
    var x: CGFloat = 0
    while x <= W { grid.move(to: NSPoint(x: x, y: 0)); grid.line(to: NSPoint(x: x, y: H)); x += 36 }
    var y: CGFloat = 0
    while y <= H { grid.move(to: NSPoint(x: 0, y: y)); grid.line(to: NSPoint(x: W, y: y)); y += 36 }
    grid.stroke()

    // 3) 미묘한 비네트(가장자리 어둡게)로 입체감
    if let vignette = NSGradient(colors: [NSColor(white: 0, alpha: 0), NSColor(white: 0, alpha: 0.28)]) {
        vignette.draw(in: full, relativeCenterPosition: NSPoint(x: 0, y: -0.2))
    }

    // 4) 나침반 모티프: 좌상단에 옅은 호(arc) + 눈금
    let cx: CGFloat = 270, cyTop: CGFloat = H - 200 // 중앙 살짝
    _ = (cx, cyTop)
    // 좌측 아이콘 뒤로 옅은 동심 링
    accent.withAlphaComponent(0.10).setStroke()
    for r in stride(from: CGFloat(54), through: 74, by: 10) {
        let ring = NSBezierPath(ovalIn: NSRect(x: 140 - r, y: (H - 200) - r, width: 2 * r, height: 2 * r))
        ring.lineWidth = 1
        ring.stroke()
    }

    // 5) 설치 화살표: 앱 아이콘(140,200) → Applications(400,200)
    // 바닥 기준 y = 380 - 200 = 180. 아이콘(크기 100) 사이 공간 x 약 205→335.
    let arrowY: CGFloat = H - 200
    let ax0: CGFloat = 210, ax1: CGFloat = 330
    accent.withAlphaComponent(0.55).setStroke()
    accent.withAlphaComponent(0.55).setFill()
    let shaft = NSBezierPath()
    shaft.lineWidth = 3
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: ax0, y: arrowY))
    shaft.line(to: NSPoint(x: ax1 - 4, y: arrowY))
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: ax1 + 6, y: arrowY))
    head.line(to: NSPoint(x: ax1 - 12, y: arrowY + 9))
    head.line(to: NSPoint(x: ax1 - 12, y: arrowY - 9))
    head.close()
    head.fill()

    // 6) 워드마크 "AZIMUTH" (상단, 자간 넓힘)
    func drawText(_ s: String, font: NSFont, color: NSColor, centerX: CGFloat, baselineY: CGFloat, tracking: CGFloat = 0) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .kern: tracking, .paragraphStyle: para,
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: centerX - size.width / 2, y: baselineY))
    }

    drawText("AZIMUTH",
             font: NSFont.systemFont(ofSize: 26, weight: .semibold),
             color: NSColor(white: 1, alpha: 0.92),
             centerX: W / 2, baselineY: H - 56, tracking: 8)

    // 7) 하단 안내문
    drawText("Drag Azimuth onto Applications to install",
             font: NSFont.systemFont(ofSize: 12, weight: .regular),
             color: NSColor(white: 1, alpha: 0.6),
             centerX: W / 2, baselineY: 40)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scripts/dmg"
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

try! render(scale: 1).write(to: URL(fileURLWithPath: "\(outDir)/background.png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: "\(outDir)/background@2x.png"))
print("✅ wrote \(outDir)/background.png (540×380) + background@2x.png (1080×760)")
