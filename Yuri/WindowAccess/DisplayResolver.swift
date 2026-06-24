//
//  DisplayResolver.swift
//  Yuri
//
//  현재 창이 놓인 화면 기준으로, 지정 방향에 인접한 디스플레이의 작업영역을 구한다.
//  snap-or-throw(반복 시 옆 모니터로 던지기)에서 사용. 좌표 변환은 CoordinateSpace 재사용.
//

import AppKit

@MainActor
enum DisplayResolver {
    /// AX 창 frame이 놓인 화면 기준으로 `edge` 방향 인접 화면의 visibleFrame을 AX 좌표로 반환. 없으면 nil.
    static func adjacentWorkArea(forAXWindowFrame axFrame: CGRect, edge: SnapEdge) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let current = bestScreen(for: cocoaWindow),
              let neighbor = adjacentScreen(to: current, edge: edge)
        else {
            return nil
        }
        return CoordinateSpace.cocoaToAX(neighbor.visibleFrame)
    }

    private static func bestScreen(for cocoaRect: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let rect = cocoaRect.intersection(screen.frame)
            let area = rect.isNull ? 0 : rect.width * rect.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// Cocoa 좌표(원점 좌하단, Y 위로) 기준으로 방향에 맞고 수직/수평으로 겹치는 화면 중 가장 가까운 것.
    private static func adjacentScreen(to current: NSScreen, edge: SnapEdge) -> NSScreen? {
        let origin = current.frame
        var best: NSScreen?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for screen in NSScreen.screens where screen != current {
            guard let distance = directionalDistance(from: origin, to: screen.frame, edge: edge) else { continue }
            if distance < bestDistance {
                bestDistance = distance
                best = screen
            }
        }
        return best
    }

    /// `edge` 방향(AX 기준: top=위쪽=Cocoa 큰 Y)으로 올바른 쪽이고 수직/수평 겹침이 있으면 중심 간 거리, 아니면 nil.
    private static func directionalDistance(from origin: CGRect, to candidate: CGRect, edge: SnapEdge) -> CGFloat? {
        switch edge {
        case .left:
            guard candidate.midX < origin.midX, verticalOverlap(origin, candidate) else { return nil }
            return origin.midX - candidate.midX
        case .right:
            guard candidate.midX > origin.midX, verticalOverlap(origin, candidate) else { return nil }
            return candidate.midX - origin.midX
        case .top:
            guard candidate.midY > origin.midY, horizontalOverlap(origin, candidate) else { return nil }
            return candidate.midY - origin.midY
        case .bottom:
            guard candidate.midY < origin.midY, horizontalOverlap(origin, candidate) else { return nil }
            return origin.midY - candidate.midY
        }
    }

    private static func verticalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minY < rhs.maxY && rhs.minY < lhs.maxY
    }

    private static func horizontalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minX < rhs.maxX && rhs.minX < lhs.maxX
    }
}
