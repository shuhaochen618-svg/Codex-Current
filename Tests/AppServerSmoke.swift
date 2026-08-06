import Foundation

@main
struct AppServerSmoke {
    static func main() async throws {
        let client = CodexAppServerClient()
        do {
            try await client.start()
            let account = try await client.readAccount()
            guard account.account?.type == "chatgpt" else {
                throw SmokeFailure.unsupportedAccount(account.account?.type ?? "none")
            }

            async let limitsRequest = client.readRateLimits()
            async let usageRequest = client.readTokenUsage()
            async let threadsRequest = client.readRecentThreads()
            let limits = try await limitsRequest
            let usage = try await usageRequest
            let threads = try await threadsRequest

            print("App Server smoke test passed.")
            print("rate_limit_windows=\(limits.displayWindows.count)")
            print("usage_daily_buckets=\(usage.dailyUsageBuckets?.count ?? 0)")
            print("thread_summaries=\(threads.data.count)")
            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }
}

private enum SmokeFailure: Error, CustomStringConvertible {
    case unsupportedAccount(String)

    var description: String {
        switch self {
        case let .unsupportedAccount(type):
            "The current Codex account type is not supported: \(type)"
        }
    }
}
