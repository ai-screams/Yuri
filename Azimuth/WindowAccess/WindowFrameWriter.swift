import AppKit
import ApplicationServices

/// AX 쓰기는 메인 스레드에서만 안전하며 권한 캐시(@MainActor)와 PID별 복원 상태를 다루므로 @MainActor.
///
/// 쓰기 전략(메이저 윈도우 매니저 컨센서스):
///  - 대상 앱의 `AXEnhancedUserInterface`/`AXManualAccessibility`를 잠시 꺼서 AX 쓰기를 동기·비애니메이션화한다
///    (깜빡임 1차 원인 제거). VoiceOver 사용 중엔 끄지 않는다(보조기능 연결 끊김 방지).
///  - 작아질 때만 size→position 순서(줄인 뒤 이동 → 옛 큰 크기로 옆 모니터 침범 방지), 커질 땐 position→size.
///  - 제약 앱이 목표 크기에 못 미치면 실제 크기를 읽어 anchored origin을 "한 번만" 써서(KI-003 2단계 깜빡임 회피)
///    스냅 모서리를 유지한다.
@MainActor
enum WindowFrameWriter {
    private static let enhancedUIAttribute = "AXEnhancedUserInterface"
    private static let manualAccessibilityAttribute = "AXManualAccessibility"
    /// Chrome/Electron이 비동기로 다시 켜므로 즉시 복원은 레이스 → 마지막 입력 뒤 이 시간만큼 늦춰 복원.
    private static let restoreDelay: TimeInterval = 0.25
    private static let originTolerance: CGFloat = 2
    /// 크기증분 앱(Terminal)이 한 셀(≈7pt) 모자라도 헛재시도하지 않게 size 허용 오차는 넉넉히.
    private static let sizeTolerance: CGFloat = 8
    /// PID별 억제 중(복원 대기)인 원본 상태. 연속 입력 때 라이브 값은 이미 false라 재판정이 불가하므로
    /// 원본을 여기 보관해 복원 시 사용한다.
    private static var suppressed: [pid_t: RestoreState] = [:]
    /// PID별 보류 중인 복원 작업(연속 입력 시 취소·교체 → 마지막 입력 기준으로 복원 시점이 미뤄진다).
    private static var pendingRestores: [pid_t: DispatchWorkItem] = [:]

    /// `resolved`가 element/appElement/pid/현재 frame을 모두 운반한다. workArea는 anchor 보정용(undo는 nil).
    static func apply(
        _ target: CGRect,
        to resolved: ResolvedWindow,
        workArea: CGRect?
    ) -> Result<CGRect, WindowCommandError> {
        // 권한 가드를 쓰기 경계에도 둔다(방어적 — 호출 순서에 의존하지 않게).
        guard AccessibilityPermissionService.currentStatus().isTrusted else {
            return .failure(.resolution(.permissionDenied))
        }
        let element = resolved.element
        guard isSettable(element, kAXPositionAttribute), isSettable(element, kAXSizeAttribute) else {
            return .failure(.notMovable)
        }

        let didSuppress = suppressAnimations(appElement: resolved.appElement, pid: resolved.pid)
        let result = writeFrame(target, to: element, current: resolved.frame.rect, workArea: workArea)
        if didSuppress { scheduleRestore(pid: resolved.pid) }
        return result
    }

    // MARK: - 프레임 쓰기

    private static func writeFrame(
        _ target: CGRect,
        to element: AXUIElement,
        current: CGRect,
        workArea: CGRect?
    ) -> Result<CGRect, WindowCommandError> {
        let shrinking = target.width < current.width - 1 || target.height < current.height - 1
        // (1) 작아질 때만 size-first: 줄인 뒤 이동해야 옛 큰 크기로 옆 모니터를 침범하지 않는다.
        if shrinking { setSize(element, kAXSizeAttribute, target.size) }

        // (2) 제약 앱이 목표보다 큰 크기에 머물면 실제 크기를 읽어 anchored origin을 "한 번만" 쓴다(위치 1회).
        let origin = anchoredOrigin(element: element, target: target, workArea: workArea)
        let positionError = setPoint(element, kAXPositionAttribute, origin)
        // (3) 크기 재확정(모니터를 넘어가며 클램프됐을 수 있음).
        let sizeError = setSize(element, kAXSizeAttribute, target.size)

        // (4) verify + 1회 재시도(비동기·부분수용 앱). size는 8pt 오차 허용(증분 앱 헛재시도 방지).
        // 재시도 origin은 방금 읽힌 실제 크기로 다시 anchor 계산(첫 추정이 어긋났을 때 보정).
        if let achieved = readFrame(element), !frameMatches(achieved, origin: origin, size: target.size) {
            let retryOrigin = anchoredOrigin(element: element, target: target, workArea: workArea)
            setPoint(element, kAXPositionAttribute, retryOrigin)
            setSize(element, kAXSizeAttribute, target.size)
        }

        guard positionError == .success, sizeError == .success else {
            // Space 전환·애니메이션 중엔 cannotComplete가 흔하다 → 일시적 실패로 구분(조용히 스킵).
            let isTransient = positionError == .cannotComplete || sizeError == .cannotComplete
            return .failure(isTransient ? .transient : .applyFailed)
        }
        guard let achieved = readFrame(element) else { return .failure(.applyFailed) }
        return .success(achieved)
    }

    /// 제약 앱이 목표보다 크게 머물면 anchored origin, 아니면 목표 origin. workArea 없으면(undo) 항상 목표.
    private static func anchoredOrigin(element: AXUIElement, target: CGRect, workArea: CGRect?) -> CGPoint {
        guard let workArea,
              let achieved = AXAttribute.size(element, kAXSizeAttribute as String),
              achieved.width > target.width + sizeTolerance || achieved.height > target.height + sizeTolerance
        else { return target.origin }
        return FrameCalculator.anchorOrigin(actualSize: achieved, requested: target, workArea: workArea)
    }

    // MARK: - 애니메이션 억제(enhancedUI / manualAccessibility)

    private struct RestoreState {
        let appElement: AXUIElement
        let enhanced: Bool
        let manual: Bool
    }

    /// 쓰기 전 애니메이션 속성을 끈다. 복원 스케줄이 필요하면 true 반환.
    /// 이미 같은 앱을 억제 중이면 라이브 값이 false라 재판정 불가 → 원본을 그대로 유지하고 복원만 미룬다(true).
    private static func suppressAnimations(appElement: AXUIElement, pid: pid_t) -> Bool {
        // VoiceOver 사용 중엔 토글하지 않는다(화면낭독 연결이 끊겨 멈추는 것 방지 — 스냅 정밀도보다 우선).
        if NSWorkspace.shared.isVoiceOverEnabled { return false }
        // 연속 입력: 이미 끈 상태이므로 복원만 다시 미루면 된다(마지막 입력 기준 디바운스).
        // 단, pid 재사용(원래 앱이 죽고 같은 pid의 다른 앱)일 수 있으니 엘리먼트 동일성으로 확인한다.
        if let existing = suppressed[pid], existing.appElement == appElement { return true }
        let enhanced = AXAttribute.bool(appElement, enhancedUIAttribute) == true
        let manual = AXAttribute.bool(appElement, manualAccessibilityAttribute) == true
        // 둘 다 꺼져있거나 없으면(네이티브 AppKit 앱) 건드릴 필요 없음 — 부작용·IPC 0.
        guard enhanced || manual else { return false }
        if enhanced { setBool(appElement, enhancedUIAttribute, false) }
        if manual { setBool(appElement, manualAccessibilityAttribute, false) }
        suppressed[pid] = RestoreState(appElement: appElement, enhanced: enhanced, manual: manual)
        return true
    }

    /// 마지막 입력 +restoreDelay에 원본 상태로 복원. 연속 입력 시 직전 작업을 취소·교체해 시점이 미뤄진다.
    /// 복원 대상 엘리먼트는 suppressed[pid]에 보관된 것을 쓴다(pid 재사용 시 새 앱으로 덮여 있어 일관적).
    private static func scheduleRestore(pid: pid_t) {
        pendingRestores[pid]?.cancel()
        let work = DispatchWorkItem {
            MainActor.assumeIsolated {
                if let state = suppressed[pid] {
                    if state.enhanced { setBool(state.appElement, enhancedUIAttribute, true) }
                    if state.manual { setBool(state.appElement, manualAccessibilityAttribute, true) }
                }
                suppressed[pid] = nil
                pendingRestores[pid] = nil
            }
        }
        pendingRestores[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }

    // MARK: - AX 래퍼

    private static func readFrame(_ element: AXUIElement) -> CGRect? {
        guard let origin = AXAttribute.point(element, kAXPositionAttribute as String),
              let size = AXAttribute.size(element, kAXSizeAttribute as String)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func approx(_ lhs: CGPoint, _ rhs: CGPoint, tol: CGFloat) -> Bool {
        abs(lhs.x - rhs.x) <= tol && abs(lhs.y - rhs.y) <= tol
    }

    private static func approx(_ lhs: CGSize, _ rhs: CGSize, tol: CGFloat) -> Bool {
        abs(lhs.width - rhs.width) <= tol && abs(lhs.height - rhs.height) <= tol
    }

    /// 읽어온 frame이 목표 origin·size에 (허용오차 내) 도달했는가. 재시도 판정에 쓴다.
    private static func frameMatches(_ frame: CGRect, origin: CGPoint, size: CGSize) -> Bool {
        approx(frame.origin, origin, tol: originTolerance) && approx(frame.size, size, tol: sizeTolerance)
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }

    @discardableResult
    private static func setBool(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)
    }

    @discardableResult
    private static func setPoint(_ element: AXUIElement, _ attribute: String, _ point: CGPoint) -> AXError {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    @discardableResult
    private static func setSize(_ element: AXUIElement, _ attribute: String, _ size: CGSize) -> AXError {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
