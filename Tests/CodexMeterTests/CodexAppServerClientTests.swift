import Foundation
import CodexMeterCore

let codexAppServerClient: [HarnessTest] = [
    HarnessTest(
        suite: "protocol",
        name: "App Server client initializes once and decodes read methods",
        body: testAppServerRoundTrip
    ),
    HarnessTest(
        suite: "protocol",
        name: "App Server client surfaces protocol errors",
        body: testAppServerError
    ),
    HarnessTest(
        suite: "protocol",
        name: "Concurrent requests share one recovery after helper exit",
        body: testConcurrentRecovery
    ),
    HarnessTest(
        suite: "protocol",
        name: "Shutdown cancels a pending request without restarting",
        body: testShutdownDuringRequest
    )
]

private func testAppServerRoundTrip() async throws {
    let script = try makeFakeCodex(
        body: #"""
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*)
              printf '%s\n' '{"id":1,"result":{"userAgent":"fake"}}'
              ;;
            *refreshToken*)
              printf '%s\n' '{"id":2,"result":{"account":{"type":"chatgpt","email":"test@example.com","planType":"plus"},"requiresOpenaiAuth":true}}'
              ;;
            *rateLimits*read*)
              printf '%s\n' '{"id":3,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":12,"windowDurationMins":300}}}}'
              ;;
            *config*read*)
              printf '%s\n' '{"id":4,"result":{"config":{"model":"gpt-test"}}}'
              ;;
          esac
        done
        """#
    )
    defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }

    let client = CodexAppServerClient(executableURL: script, requestTimeout: 2)
    let account = try await client.account()
    let limits = try await client.rateLimits()
    let config = try await client.effectiveConfig()
    await client.shutdown()

    expectEqual(account.account?.email, "test@example.com")
    expectEqual(limits.rateLimits.primary?.usedPercent, 12)
    expectEqual(config.config.model, "gpt-test")
}

private func testAppServerError() async throws {
    let script = try makeFakeCodex(
        body: #"""
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*)
              printf '%s\n' '{"id":1,"result":{}}'
              ;;
            *refreshToken*)
              printf '%s\n' '{"id":2,"error":{"code":-32000,"message":"unavailable"}}'
              ;;
          esac
        done
        """#
    )
    defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }

    let client = CodexAppServerClient(executableURL: script, requestTimeout: 2)
    do {
        _ = try await client.account()
        TestRecorder.record("expected server error")
    } catch let error as CodexAppServerClientError {
        expectEqual(error, .serverError(code: -32_000, message: "unavailable"))
    } catch {
        TestRecorder.record("unexpected error: \(error)")
    }
    await client.shutdown()
}

private func testConcurrentRecovery() async throws {
    let script = try makeFakeCodex(
        body: #"""
        state_file="$0.launches"
        launches=$(sed -n '1p' "$state_file" 2>/dev/null)
        launches=${launches:-0}
        launches=$((launches + 1))
        printf '%s\n' "$launches" > "$state_file"

        while IFS= read -r line; do
          id=$(printf '%s\n' "$line" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
          case "$line" in
            *'"method":"initialize"'*)
              printf '{"id":%s,"result":{}}\n' "$id"
              ;;
            *refreshToken*)
              printf '{"id":%s,"result":{"account":{"type":"chatgpt"},"requiresOpenaiAuth":true}}\n' "$id"
              ;;
            *rateLimits*|*includeLayers*)
              if [ "$launches" -eq 1 ]; then
                exit 1
              elif printf '%s' "$line" | grep -q rateLimits; then
                printf '{"id":%s,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":20,"windowDurationMins":300}}}}\n' "$id"
              else
                printf '{"id":%s,"result":{"config":{"model":"gpt-recovered"}}}\n' "$id"
              fi
              ;;
          esac
        done
        """#
    )
    defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }

    let client = CodexAppServerClient(executableURL: script, requestTimeout: 2)
    _ = try await client.account()

    async let limitsRequest = client.rateLimits()
    async let configRequest = client.effectiveConfig()
    let (limits, config) = try await (limitsRequest, configRequest)
    await client.shutdown()

    let launchCountURL = URL(fileURLWithPath: script.path + ".launches")
    let launchCount = try String(contentsOf: launchCountURL)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    expectEqual(limits.rateLimits.primary?.usedPercent, 20)
    expectEqual(config.config.model, "gpt-recovered")
    expectEqual(launchCount, "2")
}

private func testShutdownDuringRequest() async throws {
    let script = try makeFakeCodex(
        body: #"""
        state_file="$0.launches"
        launches=$(sed -n '1p' "$state_file" 2>/dev/null)
        launches=${launches:-0}
        launches=$((launches + 1))
        printf '%s\n' "$launches" > "$state_file"

        while IFS= read -r line; do
          id=$(printf '%s\n' "$line" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
          case "$line" in
            *'"method":"initialize"'*)
              printf '{"id":%s,"result":{}}\n' "$id"
              ;;
            *refreshToken*)
              # Deliberately keep the request pending until the client closes stdin.
              ;;
          esac
        done
        """#
    )
    defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }

    let client = CodexAppServerClient(executableURL: script, requestTimeout: 2)
    let requestTask = Task { () -> CodexAppServerClientError? in
        do {
            _ = try await client.account()
            return nil
        } catch let error as CodexAppServerClientError {
            return error
        } catch {
            return .processUnavailable
        }
    }

    let launchCountURL = URL(fileURLWithPath: script.path + ".launches")
    for _ in 0..<100 where !FileManager.default.fileExists(atPath: launchCountURL.path) {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    await client.shutdown()
    let requestError = await requestTask.value
    try await Task.sleep(nanoseconds: 50_000_000)

    let launchCount = try String(contentsOf: launchCountURL)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    expectEqual(requestError, .shutDown)
    expectEqual(launchCount, "1")
}

private func makeFakeCodex(body: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let executable = root.appendingPathComponent("codex")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("#!/bin/sh\n\(body)\n".utf8).write(to: executable)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executable.path
    )
    return executable
}
