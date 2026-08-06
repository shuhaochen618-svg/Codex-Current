import Foundation
import SystemConfiguration

struct VPNStatusClient: Sendable {
    func fetch() async -> VPNStatusSnapshot {
        await Task.detached(priority: .utility) {
            fetchSynchronously()
        }.value
    }

    private func fetchSynchronously() -> VPNStatusSnapshot {
        let systemProxyEnabled = hasEnabledSystemProxy()
        let socket = mihomoSocket()

        guard let socket else {
            return VPNStatusSnapshot(
                state: systemProxyEnabled ? .partial : .disconnected,
                provider: "System proxy",
                mode: nil,
                group: nil,
                node: nil,
                latencyMilliseconds: nil,
                nodeAlive: nil,
                systemProxyEnabled: systemProxyEnabled,
                tunnelEnabled: false,
                updatedAt: Date()
            )
        }

        guard
            let config = queryJSON(socket: socket, endpoint: "configs"),
            let proxies = queryJSON(socket: socket, endpoint: "proxies")
        else {
            return VPNStatusSnapshot(
                state: .unavailable,
                provider: "Clash Verge / Mihomo",
                mode: nil,
                group: nil,
                node: nil,
                latencyMilliseconds: nil,
                nodeAlive: nil,
                systemProxyEnabled: systemProxyEnabled,
                tunnelEnabled: false,
                updatedAt: Date()
            )
        }

        let mode = config["mode"] as? String
        let tunnelEnabled = ((config["tun"] as? [String: Any])?["enable"] as? Bool) ?? false
        let selection = selectedAIProxy(from: proxies)
        let state: VPNStatusSnapshot.State
        if selection.alive == false {
            state = .disconnected
        } else if systemProxyEnabled || tunnelEnabled {
            state = .connected
        } else {
            state = .partial
        }

        return VPNStatusSnapshot(
            state: state,
            provider: "Clash Verge / Mihomo",
            mode: mode,
            group: selection.group,
            node: selection.node,
            latencyMilliseconds: selection.delay,
            nodeAlive: selection.alive,
            systemProxyEnabled: systemProxyEnabled,
            tunnelEnabled: tunnelEnabled,
            updatedAt: Date()
        )
    }

    private func hasEnabledSystemProxy() -> Bool {
        guard let proxies = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
            return false
        }
        let keys = [
            kSCPropNetProxiesHTTPEnable as String,
            kSCPropNetProxiesHTTPSEnable as String,
            kSCPropNetProxiesSOCKSEnable as String,
            kSCPropNetProxiesProxyAutoConfigEnable as String
        ]
        return keys.contains { key in
            (proxies[key] as? NSNumber)?.boolValue == true
        }
    }

    private func mihomoSocket() -> String? {
        let candidates = [
            "/tmp/verge/verge-mihomo.sock",
            "/tmp/clash-verge-service.sock",
            "/tmp/mihomo.sock"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func queryJSON(socket: String, endpoint: String) -> [String: Any]? {
        guard
            let result = try? LocalProcessRunner.run(
                "/usr/bin/curl",
                arguments: [
                    "--silent",
                    "--show-error",
                    "--max-time", "2",
                    "--unix-socket", socket,
                    "http://localhost/\(endpoint)"
                ]
            ),
            result.status == 0,
            let object = try? JSONSerialization.jsonObject(with: result.stdout) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private func selectedAIProxy(
        from response: [String: Any]
    ) -> (group: String?, node: String?, alive: Bool?, delay: Int?) {
        guard let proxies = response["proxies"] as? [String: [String: Any]] else {
            return (nil, nil, nil, nil)
        }

        let aiGroup = proxies.keys
            .sorted()
            .first { name in
                name.range(of: "AI", options: .caseInsensitive) != nil
                    || name.range(of: "ChatGPT", options: .caseInsensitive) != nil
                    || name.range(of: "OpenAI", options: .caseInsensitive) != nil
            }
        let selectorGroup = proxies.keys.sorted().first { key in
            let type = proxies[key]?["type"] as? String
            return type == "Selector" || type == "URLTest" || type == "Fallback"
        }
        let groupName = aiGroup ?? (proxies["GLOBAL"] == nil ? selectorGroup : "GLOBAL")
        guard let groupName, let group = proxies[groupName] else {
            return (nil, nil, nil, nil)
        }

        var nodeName = group["now"] as? String
        var node = nodeName.flatMap { proxies[$0] }
        var visited = Set<String>()
        while
            let currentName = nodeName,
            !visited.contains(currentName),
            let nextName = node?["now"] as? String,
            proxies[nextName] != nil
        {
            visited.insert(currentName)
            nodeName = nextName
            node = proxies[nextName]
        }

        let history = node?["history"] as? [[String: Any]]
        let delay = history?.last?["delay"] as? Int
        let alive = (node?["alive"] as? Bool) ?? (group["alive"] as? Bool)
        return (groupName, nodeName, alive, delay)
    }
}
