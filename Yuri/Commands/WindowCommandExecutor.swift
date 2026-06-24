import Cocoa

@MainActor
enum WindowCommandExecutor {
    static func run(
        _ command: WindowCommand,
        on app: NSRunningApplication,
        undoStore: WindowUndoStore
    ) -> Result<CGRect, WindowCommandError> {
        let resolved: ResolvedWindow
        switch FocusedWindowResolver.resolveFocusedWindow(for: app) {
        case let .success(window):
            resolved = window
        case let .failure(error):
            return .failure(.resolution(error))
        }

        if command == .undo {
            guard let previous = undoStore.previousFrame(for: resolved.element, pid: resolved.pid) else {
                return .failure(.noUndoState)
            }
            let result = WindowFrameWriter.apply(previous, to: resolved.element)
            if case .success = result {
                // 1단계 복원이므로 소비한 entry는 제거(반복 undo 방지 + 누적 방지).
                undoStore.clear(for: resolved.element)
            }
            return result
        }

        guard let workArea = WorkAreaResolver.workArea(forAXWindowFrame: resolved.frame.rect) else {
            return .failure(.workAreaUnavailable)
        }

        // 일반 명령은 적용 직전 현재 frame을 1단계 저장(되돌리기용).
        undoStore.record(resolved.frame.rect, pid: resolved.pid, for: resolved.element)
        let target = targetFrame(for: command, current: resolved.frame.rect, workArea: workArea)
        return WindowFrameWriter.apply(target, to: resolved.element)
    }

    /// snapThrow만 인접 디스플레이를 알아야 하므로 여기서 분기하고, 나머지는 순수 FrameCalculator에 위임한다.
    private static func targetFrame(for command: WindowCommand, current: CGRect, workArea: CGRect) -> CGRect {
        if case let .snapThrow(edge) = command {
            return snapThrowTarget(edge, current: current, workArea: workArea)
        }
        return FrameCalculator.targetFrame(for: command, current: current, workArea: workArea)
    }

    /// 이미 그 방향 절반이면 인접 디스플레이의 반대쪽 절반으로 던지고, 아니면 현재 화면의 그 절반으로 스냅한다.
    private static func snapThrowTarget(_ edge: SnapEdge, current: CGRect, workArea: CGRect) -> CGRect {
        let half = FrameCalculator.halfRect(edge, workArea: workArea)
        guard approximatelyEqual(current, half) else { return half }
        let adjacent = DisplayResolver.adjacentWorkArea(forAXWindowFrame: current, edge: edge)
        return adjacent.map { FrameCalculator.halfRect(edge.opposite, workArea: $0) } ?? half
    }

    /// 최소 크기 제약·재적용 오차를 흡수하기 위한 허용오차 비교.
    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 6) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    static func run(
        _ command: WindowCommand,
        tracker: FrontmostAppTracker,
        undoStore: WindowUndoStore
    ) -> Result<CGRect, WindowCommandError> {
        guard let app = tracker.targetApplication else {
            return .failure(.resolution(.noFrontmostApplication))
        }
        return run(command, on: app, undoStore: undoStore)
    }
}
