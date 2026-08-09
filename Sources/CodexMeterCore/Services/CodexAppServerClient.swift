import Foundation

public enum CodexAppServerClientError: Error, Equatable, Sendable {
    case requestTimedOut
    case processUnavailable
    case invalidResponse
    case serverError(code: Int, message: String?)
    case shutDown
}

public actor CodexAppServerClient: CodexClientProtocol {
    private struct GenerationFailure: Error {
        let generation: Int
        let underlying: Error
    }

    private struct InitializationAttempt {
        let generation: Int
        let task: Task<Void, Error>
    }

    private struct PendingRequest {
        let continuation: CheckedContinuation<Data, Error>
        let timeoutTask: Task<Void, Never>
    }

    private let executableURL: URL
    private let requestTimeout: TimeInterval
    private let processEnvironment: [String: String]
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var outputContinuation: AsyncStream<Data>.Continuation?
    private var outputBuffer = Data()
    private var readerTask: Task<Void, Never>?
    private var initializationTask: InitializationAttempt?
    private var initialized = false
    private var processGeneration = 0
    private var isShutDown = false
    private var nextRequestID = 1
    private var pending: [Int: PendingRequest] = [:]

    public init(
        executableURL: URL,
        requestTimeout: TimeInterval = 15,
        processEnvironment: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.requestTimeout = requestTimeout
        self.processEnvironment = processEnvironment
    }

    public init(
        locator: CodexExecutableLocator = CodexExecutableLocator(),
        requestTimeout: TimeInterval = 15,
        processEnvironment: [String: String] = [:]
    ) throws {
        self.executableURL = try locator.locate()
        self.requestTimeout = requestTimeout
        self.processEnvironment = processEnvironment
    }

    public func account() async throws -> CodexAccountResponse {
        try await request(
            CodexAccountResponse.self,
            method: "account/read",
            params: ["refreshToken": false]
        )
    }

    public func rateLimits() async throws -> CodexRateLimitsResponse {
        try await request(
            CodexRateLimitsResponse.self,
            method: "account/rateLimits/read"
        )
    }

    public func effectiveConfig() async throws -> CodexConfigResponse {
        try await request(
            CodexConfigResponse.self,
            method: "config/read",
            params: ["includeLayers": false]
        )
    }

    public func tokenUsage() async throws -> CodexTokenUsageResponse {
        try await request(
            CodexTokenUsageResponse.self,
            method: "account/usage/read"
        )
    }

    public func shutdown() async {
        isShutDown = true
        stopProcess(resumingPendingWith: .shutDown)
    }

    private func request<Response: Decodable>(
        _ responseType: Response.Type,
        method: String,
        params: [String: Any]? = nil
    ) async throws -> Response {
        let data = try await requestData(method: method, params: params)
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw CodexAppServerClientError.invalidResponse
        }
    }

    private func requestData(
        method: String,
        params: [String: Any]?
    ) async throws -> Data {
        guard !isShutDown else {
            throw CodexAppServerClientError.shutDown
        }

        var hasRetried = false

        while true {
            guard !isShutDown else {
                throw CodexAppServerClientError.shutDown
            }

            do {
                let generation = try await ensureInitialized()
                do {
                    return try await sendRequest(
                        method: method,
                        params: params,
                        generation: generation
                    )
                } catch {
                    throw GenerationFailure(
                        generation: generation,
                        underlying: error
                    )
                }
            } catch let failure as GenerationFailure {
                guard !hasRetried, isRecoverable(failure.underlying) else {
                    throw failure.underlying
                }

                hasRetried = true
                stopProcess(
                    ifGeneration: failure.generation,
                    resumingPendingWith: .processUnavailable
                )
            } catch {
                throw error
            }
        }
    }

    private func ensureInitialized() async throws -> Int {
        guard !isShutDown else {
            throw CodexAppServerClientError.shutDown
        }

        if initialized {
            return processGeneration
        }

        if let attempt = initializationTask {
            do {
                try await attempt.task.value
                return attempt.generation
            } catch {
                throw generationFailure(error, generation: attempt.generation)
            }
        }

        let generation = try startProcess()
        let task = Task { [weak self] in
            guard let self else {
                throw CodexAppServerClientError.processUnavailable
            }
            try await self.performInitialization(generation: generation)
        }
        initializationTask = InitializationAttempt(
            generation: generation,
            task: task
        )

        do {
            try await task.value
            guard processGeneration == generation, process != nil else {
                throw CodexAppServerClientError.processUnavailable
            }
            if initializationTask?.generation == generation {
                initialized = true
                initializationTask = nil
            }
            return generation
        } catch {
            if initializationTask?.generation == generation {
                initializationTask = nil
            }
            throw generationFailure(error, generation: generation)
        }
    }

    private func performInitialization(generation: Int) async throws {
        _ = try await sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "CodexMeter",
                    "title": "CodexMeter",
                    "version": "0.1.0"
                ],
                "capabilities": ["experimentalApi": true]
            ],
            generation: generation
        )
        try sendNotification(method: "initialized", generation: generation)
    }

    private func startProcess() throws -> Int {
        guard !isShutDown else {
            throw CodexAppServerClientError.shutDown
        }

        guard process == nil else { return processGeneration }

        processGeneration &+= 1
        let generation = processGeneration

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        var environment = ProcessInfo.processInfo.environment
        for key in [
            "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY",
            "http_proxy", "https_proxy", "all_proxy"
        ] {
            environment.removeValue(forKey: key)
        }
        environment.merge(
            processEnvironment,
            uniquingKeysWith: { _, configured in configured }
        )
        process.environment = environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        let stream = AsyncStream<Data>.makeStream()
        let outputStream = stream.stream
        let streamContinuation = stream.continuation
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                streamContinuation.finish()
            } else {
                streamContinuation.yield(data)
            }
        }
        errorHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }

        process.terminationHandler = { [weak self, weak process] _ in
            guard let self, let process else { return }
            Task {
                await self.processDidExit(process, generation: generation)
            }
        }

        self.process = process
        inputHandle = inputPipe.fileHandleForWriting
        self.outputHandle = outputHandle
        self.errorHandle = errorHandle
        outputContinuation = streamContinuation
        readerTask = Task(priority: .utility) { [weak self] in
            for await data in outputStream {
                await self?.consumeOutput(data)
            }
        }

        do {
            try process.run()
        } catch {
            stopProcess(
                ifGeneration: generation,
                resumingPendingWith: .processUnavailable
            )
            throw GenerationFailure(
                generation: generation,
                underlying: CodexAppServerClientError.processUnavailable
            )
        }

        return generation
    }

    private func sendRequest(
        method: String,
        params: [String: Any]? = nil,
        generation: Int
    ) async throws -> Data {
        guard !isShutDown else {
            throw CodexAppServerClientError.shutDown
        }
        guard generation == processGeneration, process != nil else {
            throw CodexAppServerClientError.processUnavailable
        }

        let requestID = nextRequestID
        nextRequestID += 1

        var message: [String: Any] = [
            "id": requestID,
            "method": method
        ]
        if let params {
            message["params"] = params
        }

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self, requestTimeout] in
                let nanoseconds = UInt64(max(0.001, requestTimeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await self?.requestDidTimeOut(requestID)
            }
            pending[requestID] = PendingRequest(
                continuation: continuation,
                timeoutTask: timeoutTask
            )

            do {
                try write(message, generation: generation)
            } catch {
                guard let request = pending.removeValue(forKey: requestID) else { return }
                request.timeoutTask.cancel()
                request.continuation.resume(
                    throwing: CodexAppServerClientError.processUnavailable
                )
            }
        }
    }

    private func sendNotification(method: String, generation: Int) throws {
        try write(["method": method], generation: generation)
    }

    private func write(_ message: [String: Any], generation: Int) throws {
        guard generation == processGeneration, let inputHandle else {
            throw CodexAppServerClientError.processUnavailable
        }

        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        do {
            try inputHandle.write(contentsOf: data)
        } catch {
            throw CodexAppServerClientError.processUnavailable
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newlineIndex = outputBuffer.firstIndex(of: 0x0A) {
            let lineData = outputBuffer[..<newlineIndex]
            outputBuffer.removeSubrange(...newlineIndex)
            handleResponseLine(Data(lineData))
        }
    }

    private func handleResponseLine(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestID = (object["id"] as? NSNumber)?.intValue,
              let request = pending.removeValue(forKey: requestID) else {
            return
        }

        request.timeoutTask.cancel()

        if let error = object["error"] as? [String: Any] {
            let code = (error["code"] as? NSNumber)?.intValue ?? -1
            let message = error["message"] as? String
            request.continuation.resume(
                throwing: CodexAppServerClientError.serverError(
                    code: code,
                    message: message
                )
            )
            return
        }

        guard let result = object["result"],
              let resultData = try? JSONSerialization.data(
                withJSONObject: result,
                options: .fragmentsAllowed
              ) else {
            request.continuation.resume(
                throwing: CodexAppServerClientError.invalidResponse
            )
            return
        }

        request.continuation.resume(returning: resultData)
    }

    private func requestDidTimeOut(_ requestID: Int) {
        guard let request = pending.removeValue(forKey: requestID) else { return }
        request.continuation.resume(
            throwing: CodexAppServerClientError.requestTimedOut
        )
    }

    private func processDidExit(_ terminatedProcess: Process, generation: Int) {
        guard process === terminatedProcess, processGeneration == generation else {
            return
        }
        stopProcess(
            ifGeneration: generation,
            resumingPendingWith: .processUnavailable
        )
    }

    private func stopProcess(
        ifGeneration generation: Int? = nil,
        resumingPendingWith error: CodexAppServerClientError
    ) {
        guard generation == nil || generation == processGeneration else { return }

        let stoppingGeneration = processGeneration
        let activeProcess = process
        process = nil
        initialized = false
        if initializationTask?.generation == stoppingGeneration {
            initializationTask?.task.cancel()
            initializationTask = nil
        }

        readerTask?.cancel()
        readerTask = nil
        outputContinuation?.finish()
        outputContinuation = nil
        outputBuffer.removeAll(keepingCapacity: false)
        outputHandle?.readabilityHandler = nil
        errorHandle?.readabilityHandler = nil

        try? inputHandle?.close()
        try? outputHandle?.close()
        try? errorHandle?.close()
        inputHandle = nil
        outputHandle = nil
        errorHandle = nil

        activeProcess?.terminationHandler = nil
        if activeProcess?.isRunning == true {
            activeProcess?.terminate()
        }

        let activeRequests = pending.values
        pending.removeAll()
        for request in activeRequests {
            request.timeoutTask.cancel()
            request.continuation.resume(throwing: error)
        }
    }

    private func isRecoverable(_ error: Error) -> Bool {
        guard let clientError = error as? CodexAppServerClientError else {
            return false
        }

        switch clientError {
        case .requestTimedOut, .processUnavailable:
            return true
        case .invalidResponse, .serverError, .shutDown:
            return false
        }
    }

    private func generationFailure(
        _ error: Error,
        generation: Int
    ) -> GenerationFailure {
        if let failure = error as? GenerationFailure {
            return failure
        }
        return GenerationFailure(generation: generation, underlying: error)
    }
}
