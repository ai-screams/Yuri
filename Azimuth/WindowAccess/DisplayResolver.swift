//
//  DisplayResolver.swift
//  Azimuth
//
//  현재 창이 놓인 화면 기준으로, 지정 방향에 인접한 디스플레이의 작업영역을 구한다.
//  snap-or-throw·다음 디스플레이 이동에서 사용. 좌표 변환은 CoordinateSpace 재사용.
//
//  인접 선택은 "위치 인식형"이다: 그 방향에 있고 현재 화면과 수직/수평으로 겹치는 후보 중,
//  창의 현재 수직(좌우 이동) 또는 수평(상하 이동) 위치에 가장 가까운 화면을 고른다.
//  (세로로 긴 모니터 왼쪽에 두 화면이 위아래로 있을 때, 창 높이에 맞는 쪽으로 가게 한다.)
//

import AppKit

@MainActor
enum DisplayResolver {
    /// AX 창 frame이 놓인 화면 기준으로 `edge` 방향 인접 화면의 visibleFrame을 AX 좌표로 반환. 없으면 nil.
    /// @MainActor: 열거형 전체가 @MainActor이므로 이 메서드도 메인 액터에서만 호출 가능 (`NSScreen.screens` 접근).
    static func adjacentWorkArea(forAXWindowFrame axFrame: CGRect, edge: SnapEdge) -> CGRect? {
        let cocoaWindow = CoordinateSpace.axToCocoa(axFrame)
        guard let current = NSScreen.bestMatch(forCocoaRect: cocoaWindow) else { return nil }
        // 현재 화면을 제외한 후보들의 frame을 순수 기하(DisplayGeometry)에 넘겨 인덱스를 고른다.
        // NSScreen 매핑만 여기서 하고, 선택 규칙(방향·겹침·거리·타이브레이크)은 테스트 가능한 순수 계층에.
        let others = NSScreen.screens.filter { $0 != current }
        guard let pick = DisplayGeometry.selectAdjacentIndex(
            current: current.frame,
            candidates: others.map(\.frame),
            window: cocoaWindow,
            edge: edge
        ) else { return nil }
        // 0크기 가드 포함(디스플레이 재구성 순간) — WorkAreaResolver와 공용 헬퍼.
        return CoordinateSpace.axWorkArea(of: others[pick])
    }
}
