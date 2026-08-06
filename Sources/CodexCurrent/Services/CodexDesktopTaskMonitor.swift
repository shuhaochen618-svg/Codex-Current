import Foundation

struct CodexDesktopTaskMonitor: Sendable {
    enum Boundary: Equatable {
        case started
        case completed
        case aborted
        case unknown
    }

    struct SessionObservation: Equatable {
        let boundary: Boundary
        let runningTask: RunningTask?
    }

    func snapshot() async -> TaskSummary {
        await Task.detached(priority: .utility) {
            snapshotSynchronously()
        }.value
    }

    static func lastBoundary(in data: Data) -> Boundary {
        parseSession(in: data).boundary
    }

    static func parseSession(in data: Data, now: Date = Date()) -> SessionObservation {
        var latestUserMessage: String?
        var latestTotalTokens: Int64?
        var active: ActiveTaskAccumulator?
        var lastBoundary: Boundary = .unknown

        for rawLine in data.split(separator: 0x0A) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(rawLine))
                    as? [String: Any],
                let type = object["type"] as? String
            else {
                continue
            }

            if type == "turn_context" {
                guard
                    let payload = object["payload"] as? [String: Any],
                    let turnID = payload["turn_id"] as? String,
                    turnID == active?.id
                else {
                    continue
                }
                active?.model = payload["model"] as? String
                active?.reasoningEffort = payload["effort"] as? String
                continue
            }

            guard
                type == "event_msg",
                let payload = object["payload"] as? [String: Any],
                let eventType = payload["type"] as? String
            else {
                continue
            }

            switch eventType {
            case "user_message":
                let title = summarizedTitle(payload["message"] as? String)
                if let title {
                    let continuationOnly = isContinuationOnly(title)
                    if !continuationOnly || latestUserMessage == nil {
                        latestUserMessage = title
                    }
                    if active != nil, !continuationOnly || active?.title == nil {
                        active?.title = title
                    }
                }

            case "task_started":
                guard let turnID = payload["turn_id"] as? String else { continue }
                let startedAt = unixDate(payload["started_at"])
                    ?? isoDate(object["timestamp"] as? String)
                    ?? now
                active = ActiveTaskAccumulator(
                    id: turnID,
                    title: latestUserMessage,
                    model: nil,
                    reasoningEffort: nil,
                    startedAt: startedAt,
                    baselineTokens: latestTotalTokens,
                    tokenCount: nil
                )
                lastBoundary = .started

            case "token_count":
                guard
                    let info = payload["info"] as? [String: Any],
                    let totalUsage = info["total_token_usage"] as? [String: Any],
                    let total = int64(totalUsage["total_tokens"])
                else {
                    continue
                }

                if active != nil {
                    if active?.baselineTokens == nil,
                       let lastUsage = info["last_token_usage"] as? [String: Any],
                       let last = int64(lastUsage["total_tokens"])
                    {
                        active?.baselineTokens = max(0, total - last)
                    }
                    if let baseline = active?.baselineTokens {
                        active?.tokenCount = max(0, total - baseline)
                    }
                }
                latestTotalTokens = total

            case "task_complete":
                guard matchesActiveTurn(payload: payload, active: active) else { continue }
                active = nil
                lastBoundary = .completed

            case "turn_aborted":
                guard matchesActiveTurn(payload: payload, active: active) else { continue }
                active = nil
                lastBoundary = .aborted

            default:
                continue
            }
        }

        let runningTask = active.map {
            RunningTask(
                id: $0.id,
                title: $0.title,
                model: $0.model,
                reasoningEffort: $0.reasoningEffort,
                startedAt: $0.startedAt,
                tokenCount: $0.tokenCount
            )
        }
        return SessionObservation(boundary: lastBoundary, runningTask: runningTask)
    }

    private func snapshotSynchronously() -> TaskSummary {
        let pids = chatGPTAppServerPIDs()
        let sessionFiles = Set(pids.flatMap(openSessionFiles(for:)))
        let now = Date()
        var summary = TaskSummary(updatedAt: now)
        summary.observed = sessionFiles.count

        for path in sessionFiles {
            guard let tail = readTail(of: path) else { continue }
            let observation = Self.parseSession(in: tail, now: now)
            if let task = observation.runningTask {
                summary.runningTasks.append(task)
            }
            switch observation.boundary {
            case .started:
                break
            case .aborted:
                summary.failed += 1
            case .completed, .unknown:
                break
            }
        }
        summary.runningTasks.sort { $0.startedAt > $1.startedAt }
        return summary
    }

    private func chatGPTAppServerPIDs() -> [Int] {
        guard
            let result = try? LocalProcessRunner.run(
                "/bin/ps",
                arguments: ["-axo", "pid=,ppid=,args="]
            ),
            result.status == 0
        else {
            return []
        }

        let text = String(decoding: result.stdout, as: UTF8.self)
        var processes: [(pid: Int, parent: Int, args: String)] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(maxSplits: 2, whereSeparator: \.isWhitespace)
            guard
                parts.count == 3,
                let pid = Int(parts[0]),
                let parent = Int(parts[1])
            else {
                continue
            }
            processes.append((pid, parent, String(parts[2])))
        }

        let chatGPTPIDs = Set(
            processes
                .filter { $0.args.contains("ChatGPT.app/Contents/MacOS/ChatGPT") }
                .map(\.pid)
        )
        return processes
            .filter {
                chatGPTPIDs.contains($0.parent)
                    && $0.args.contains("/Contents/Resources/codex")
                    && $0.args.contains("app-server")
            }
            .map(\.pid)
    }

    private func openSessionFiles(for pid: Int) -> [String] {
        guard
            let result = try? LocalProcessRunner.run(
                "/usr/sbin/lsof",
                arguments: ["-Fn", "-p", "\(pid)"]
            ),
            result.status == 0
        else {
            return []
        }

        return String(decoding: result.stdout, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { rawLine -> String? in
                guard rawLine.first == "n" else { return nil }
                let path = String(rawLine.dropFirst())
                guard
                    path.contains("/.codex/sessions/"),
                    path.hasSuffix(".jsonl")
                else {
                    return nil
                }
                return path
            }
    }

    private func readTail(of path: String, maximumBytes: UInt64 = 8 * 1_024 * 1_024) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        do {
            let end = try handle.seekToEnd()
            try handle.seek(toOffset: end > maximumBytes ? end - maximumBytes : 0)
            return try handle.readToEnd()
        } catch {
            return nil
        }
    }

    private struct ActiveTaskAccumulator {
        let id: String
        var title: String?
        var model: String?
        var reasoningEffort: String?
        let startedAt: Date
        var baselineTokens: Int64?
        var tokenCount: Int64?
    }

    private static func summarizedTitle(_ message: String?) -> String? {
        guard let message else { return nil }
        let requestMarker = "## My request for Codex:"
        let relevantMessage: Substring
        if let markerRange = message.range(of: requestMarker, options: .caseInsensitive) {
            relevantMessage = message[markerRange.upperBound...]
        } else {
            relevantMessage = message[...]
        }
        let collapsed = relevantMessage
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        let limit = 72
        if collapsed.count <= limit { return collapsed }
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func matchesActiveTurn(
        payload: [String: Any],
        active: ActiveTaskAccumulator?
    ) -> Bool {
        guard let active else { return false }
        guard let turnID = payload["turn_id"] as? String else { return true }
        return turnID == active.id
    }

    private static func isContinuationOnly(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let phrases: Set<String> = [
            "继续",
            "请继续",
            "请你继续",
            "继续吧",
            "继续完成",
            "continue",
            "please continue",
            "keep going"
        ]
        return phrases.contains(normalized)
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        return nil
    }

    private static func unixDate(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: number.doubleValue)
    }

    private static func isoDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
