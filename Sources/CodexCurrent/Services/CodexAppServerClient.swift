import Foundation

actor CodexAppServerClient {
    enum ClientError: LocalizedError {
        case executableNotFound
        case notRunning
        case processExited(Int32)
        case malformedResponse
        case rpc(code: Int?, message: String)

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                "Codex CLI was not found."
            case .notRunning:
                "Codex App Server is not running."
            case let .processExited(code):
                "Codex App Server exited with status \(code)."
            case .malformedResponse:
                "Codex App Server returned an invalid response."
            case let .rpc(_, message):
                message
            }
        }
    }

    private struct InitializeParams: Encodable {
        struct ClientInfo: Encodable {
            let name: String
            let title: String
            let version: String
        }

        let clientInfo: ClientInfo
    }

    private struct EmptyResponse: Decodable {}

    private struct AccountReadParams: Encodable {
        let refreshToken: Bool
    }

    private struct ThreadListParams: Encodable {
        let archived: Bool
        let limit: Int
        let sortKey: String
        let useStateDbOnly: Bool
    }

    private struct RPCErrorBody: Decodable {
        let code: Int?
        let message: String
    }

    private var process: Process?
    private var writer: FileHandle?
    private var readerTask: Task<Void, Never>?
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var eventContinuation: AsyncStream<AppServerEvent>.Continuation?

    func start() async throws {
        if let process, process.isRunning { return }
        guard let executable = CodexExecutableLocator.locate() else {
            throw ClientError.executableNotFound
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        self.process = process
        writer = input.fileHandleForWriting

        let outputHandle = output.fileHandleForReading
        readerTask = Task { [weak self] in
            do {
                for try await line in outputHandle.bytes.lines {
                    await self?.receive(line: line)
                }
            } catch {
                await self?.failPending(with: error)
            }
        }

        process.terminationHandler = { [weak self] terminated in
            Task {
                await self?.processDidTerminate(code: terminated.terminationStatus)
            }
        }

        let params = InitializeParams(
            clientInfo: .init(
                name: "codex_current",
                title: "Codex Current",
                version: "1.0.0"
            )
        )
        let _: EmptyResponse = try await request("initialize", params: params)
        try sendNotification("initialized")
    }

    func stop() {
        readerTask?.cancel()
        readerTask = nil
        writer?.closeFile()
        writer = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        eventContinuation?.finish()
        eventContinuation = nil
        failPending(with: ClientError.notRunning)
    }

    func events() -> AsyncStream<AppServerEvent> {
        AsyncStream { continuation in
            eventContinuation = continuation
        }
    }

    func readAccount() async throws -> AccountReadResponse {
        try await request("account/read", params: AccountReadParams(refreshToken: false))
    }

    func readRateLimits() async throws -> RateLimitsResponse {
        try await request("account/rateLimits/read")
    }

    func readTokenUsage() async throws -> TokenUsageResponse {
        try await request("account/usage/read")
    }

    func readRecentThreads() async throws -> ThreadListResponse {
        try await request(
            "thread/list",
            params: ThreadListParams(
                archived: false,
                limit: 100,
                sortKey: "updated_at",
                useStateDbOnly: true
            )
        )
    }

    private func request<Response: Decodable>(_ method: String) async throws -> Response {
        try await request(method, paramsData: nil)
    }

    private func request<Params: Encodable, Response: Decodable>(
        _ method: String,
        params: Params
    ) async throws -> Response {
        let paramsData = try JSONEncoder().encode(params)
        return try await request(method, paramsData: paramsData)
    }

    private func request<Response: Decodable>(
        _ method: String,
        paramsData: Data?
    ) async throws -> Response {
        guard process?.isRunning == true, writer != nil else {
            throw ClientError.notRunning
        }

        let id = nextID
        nextID += 1
        var object: [String: Any] = ["method": method, "id": id]
        if let paramsData {
            object["params"] = try JSONSerialization.jsonObject(with: paramsData)
        }
        let payload = try JSONSerialization.data(withJSONObject: object)

        let result = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Data, Error>) in
            pending[id] = continuation
            do {
                try writeLine(payload)
            } catch {
                pending.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }

        return try JSONDecoder().decode(Response.self, from: result)
    }

    private func sendNotification(_ method: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["method": method])
        try writeLine(data)
    }

    private func writeLine(_ data: Data) throws {
        guard let writer else { throw ClientError.notRunning }
        var line = data
        line.append(0x0A)
        try writer.write(contentsOf: line)
    }

    private func receive(line: String) {
        guard let data = line.data(using: .utf8) else { return }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        if let id = object["id"] as? Int {
            guard let continuation = pending.removeValue(forKey: id) else { return }
            if let errorObject = object["error"] {
                let errorData = try? JSONSerialization.data(withJSONObject: errorObject)
                let body = errorData.flatMap { try? JSONDecoder().decode(RPCErrorBody.self, from: $0) }
                continuation.resume(
                    throwing: ClientError.rpc(
                        code: body?.code,
                        message: body?.message ?? "Unknown Codex App Server error."
                    )
                )
                return
            }

            guard let result = object["result"] else {
                continuation.resume(throwing: ClientError.malformedResponse)
                return
            }
            do {
                let resultData = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.fragmentsAllowed]
                )
                continuation.resume(returning: resultData)
            } catch {
                continuation.resume(throwing: error)
            }
            return
        }

        guard let method = object["method"] as? String else { return }
        let paramsObject = object["params"] ?? [:]
        guard
            let params = try? JSONSerialization.data(
                withJSONObject: paramsObject,
                options: [.fragmentsAllowed]
            )
        else {
            return
        }
        eventContinuation?.yield(AppServerEvent(method: method, params: params))
    }

    private func processDidTerminate(code: Int32) {
        process = nil
        writer = nil
        failPending(with: ClientError.processExited(code))
    }

    private func failPending(with error: Error) {
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
}
