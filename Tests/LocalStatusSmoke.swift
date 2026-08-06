import Foundation

@main
struct LocalStatusSmoke {
    static func main() async throws {
        let vpn = await VPNStatusClient().fetch()
        let tasks = await CodexDesktopTaskMonitor().snapshot()

        guard vpn.state == .connected else {
            throw SmokeFailure.vpnNotConnected(vpn.state.rawValue)
        }
        guard tasks.active > 0 else {
            throw SmokeFailure.noActiveTask
        }

        print("Local status smoke test passed.")
        print("vpn_provider=\(vpn.provider)")
        print("vpn_state=\(vpn.state.rawValue)")
        print("vpn_mode=\(vpn.mode ?? "unknown")")
        print("vpn_node_present=\(vpn.node != nil)")
        print("vpn_latency_ms=\(vpn.latencyMilliseconds ?? -1)")
        print("codex_desktop_active_tasks=\(tasks.active)")
        print("codex_desktop_open_sessions=\(tasks.observed)")
        for (index, task) in tasks.runningTasks.enumerated() {
            print("task_\(index + 1)_title_present=\(task.title != nil)")
            print("task_\(index + 1)_model=\(task.model ?? "unknown")")
            print("task_\(index + 1)_tokens=\(task.tokenCount ?? -1)")
            print(
                "task_\(index + 1)_elapsed_seconds="
                    + "\(max(0, Int(Date().timeIntervalSince(task.startedAt))))"
            )
        }
    }
}

private enum SmokeFailure: Error, CustomStringConvertible {
    case vpnNotConnected(String)
    case noActiveTask

    var description: String {
        switch self {
        case let .vpnNotConnected(state):
            "Expected the current VPN/proxy to be connected, got \(state)"
        case .noActiveTask:
            "Expected at least one active Codex Desktop task"
        }
    }
}
