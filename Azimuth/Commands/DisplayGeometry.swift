//
//  DisplayGeometry.swift
//  Azimuth
//
//  인접 디스플레이 "선택" 순수 기하 — 화면 frame들과 창 위치·방향만으로 어느 이웃 화면을
//  고를지 결정한다. NSScreen 같은 AppKit 타입에 의존하지 않아 단위 테스트가 가능하다
//  (DisplayResolver가 NSScreen → CGRect 매핑만 하는 얇은 wrapper로 이 로직을 호출한다).
//
//  선택 규칙(위치 인식형): 그 방향에 있고 현재 화면과 수직/수평으로 겹치는 후보 중, 창의
//  현재 수직(좌우 이동)·수평(상하 이동) 위치에 가장 가까운(perpendicularGap 최소) 화면.
//  동률(0.5pt 이내)이면 이동 방향 중심 거리(primaryGap)가 가까운 쪽.
//
//  ⚠️ 순수 로직 파일 — AppKit/AX를 import하지 말 것(scripts/test.sh가 swiftc로 직접 컴파일).
//  CoreGraphics·SnapEdge(CommandPrimitives)만 사용.
//

import CoreGraphics

nonisolated enum DisplaygeometryConstants {
    /// perpendicularGap 동률 판정 데드밴드(pt).
    static let tieDeadband: CGFloat = 0.5
}

nonisolated enum DisplayGeometry {
    /// `current`(현재 화면 frame) 기준 `edge` 방향 인접 후보를 고른다. `candidates`는 현재 화면을
    /// 제외한 다른 화면들의 frame(Cocoa 좌표). 선택된 후보의 인덱스를 반환하고, 없으면 nil.
    /// 좌표계는 호출자가 일관되게 넘기면 무관(현재는 Cocoa: 원점 좌하단, Y 위로).
    static func selectAdjacentIndex(
        current: CGRect,
        candidates: [CGRect],
        window: CGRect,
        edge: SnapEdge
    ) -> Int? {
        var best: Int?
        var bestPerpendicular = CGFloat.greatestFiniteMagnitude
        var bestPrimary = CGFloat.greatestFiniteMagnitude
        for (index, candidate) in candidates.enumerated() {
            guard isInDirection(origin: current, candidate: candidate, edge: edge) else { continue }
            let perpendicular = perpendicularGap(window: window, candidate: candidate, edge: edge)
            let primary = primaryGap(origin: current, candidate: candidate, edge: edge)
            let closerPerpendicular = perpendicular < bestPerpendicular - DisplaygeometryConstants.tieDeadband
            let tiedPerpendicular = abs(perpendicular - bestPerpendicular) <= DisplaygeometryConstants.tieDeadband
                && primary < bestPrimary
            if closerPerpendicular || tiedPerpendicular {
                bestPerpendicular = perpendicular
                bestPrimary = primary
                best = index
            }
        }
        return best
    }

    /// `edge` 방향에 있고 수직/수평으로 겹치는가. 그 방향의 모든 화면이 후보(물리적 인접 한정 아님);
    /// 최종 선택은 거리 기준(가장 가까운 화면이 이긴다).
    static func isInDirection(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> Bool {
        switch edge {
        case .left:
            return candidate.midX < origin.midX && verticalOverlap(origin, candidate)
        case .right:
            return candidate.midX > origin.midX && verticalOverlap(origin, candidate)
        case .top:
            return candidate.midY > origin.midY && horizontalOverlap(origin, candidate)
        case .bottom:
            return candidate.midY < origin.midY && horizontalOverlap(origin, candidate)
        }
    }

    /// 창의 수직(좌우 이동)·수평(상하 이동) 중심이 후보 화면 범위에서 벗어난 거리(범위 안이면 0).
    static func perpendicularGap(window: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left, .right:
            return distance(window.midY, lower: candidate.minY, upper: candidate.maxY)
        case .top, .bottom:
            return distance(window.midX, lower: candidate.minX, upper: candidate.maxX)
        }
    }

    /// 이동 방향(주축) 중심 거리. 동률 타이브레이크에 쓴다.
    static func primaryGap(origin: CGRect, candidate: CGRect, edge: SnapEdge) -> CGFloat {
        switch edge {
        case .left:
            return origin.midX - candidate.midX
        case .right:
            return candidate.midX - origin.midX
        case .top:
            return candidate.midY - origin.midY
        case .bottom:
            return origin.midY - candidate.midY
        }
    }

    private static func distance(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if value < lower { return lower - value }
        if value > upper { return value - upper }
        return 0
    }

    private static func verticalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minY < rhs.maxY && rhs.minY < lhs.maxY
    }

    private static func horizontalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minX < rhs.maxX && rhs.minX < lhs.maxX
    }
}
