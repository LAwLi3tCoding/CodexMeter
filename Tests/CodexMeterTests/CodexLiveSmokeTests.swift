import CodexMeterCore
import Foundation

let codexLiveSmoke: [HarnessTest] = [
    HarnessTest(
        suite: "live",
        name: "Installed Codex CLI returns a non-empty quota snapshot",
        body: testLiveCodexSnapshot
    )
]

let codexLiveUsageSmoke: [HarnessTest] = [
    HarnessTest(
        suite: "live-usage",
        name: "Installed Codex CLI returns a complete thirty-day usage dashboard",
        body: testLiveCodexUsage
    )
]

private func testLiveCodexSnapshot() async throws {
    let processEnvironment = try proxyProcessEnvironment()
    let client = try CodexAppServerClient(processEnvironment: processEnvironment)

    do {
        let snapshot = try await CodexProvider(client: client).fetchSnapshot()
        expectEqual(snapshot.provider, .codex)
        if snapshot.quotas.isEmpty {
            TestRecorder.record("expected at least one quota window")
        }
        if snapshot.plan?.lowercased() == "pro" {
            expectEqual(
                StatusPanelPresentation(snapshot: snapshot).planText,
                "PRO 20X"
            )
        }

        await client.shutdown()
    } catch {
        await client.shutdown()
        throw error
    }
}

private func testLiveCodexUsage() async throws {
    let processEnvironment = try proxyProcessEnvironment()
    let client = try CodexAppServerClient(processEnvironment: processEnvironment)
    let modelUsageReader: any ModelUsageReading
    if let databaseURL = SQLiteThreadModelUsageReader.defaultDatabaseURL() {
        modelUsageReader = SQLiteThreadModelUsageReader(databaseURL: databaseURL)
    } else {
        modelUsageReader = UnavailableModelUsageReader()
    }

    do {
        let usage = try await CodexUsageProvider(
            client: client,
            modelUsageReader: modelUsageReader
        ).fetchUsage()
        expectEqual(usage.days.count, 30)
        if let firstDayID = usage.days.first?.dayID,
           let lastDayID = usage.days.last?.dayID,
           firstDayID >= lastDayID {
            TestRecorder.record("expected thirty chronological daily buckets")
        }
        if usage.currentModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            TestRecorder.record("expected the current configured model")
        }
        if usage.thirtyDayTokens > 0 && usage.thirtyDayEstimatedCostUSD == nil {
            TestRecorder.record("expected a thirty-day USD estimate for the configured model")
        }
        await client.shutdown()
    } catch {
        await client.shutdown()
        throw error
    }
}

private enum LiveUsageError: Error {
    case invalidProxy
}

private func proxyProcessEnvironment() throws -> [String: String] {
    guard let rawProxyURL = ProcessInfo.processInfo.environment["CODEXMETER_LIVE_PROXY_URL"],
          !rawProxyURL.isEmpty else {
        return [:]
    }
    guard let resolvedProxyURL = SettingsStore.validatedLocalProxyURL(rawProxyURL) else {
        throw LiveUsageError.invalidProxy
    }
    return [
        "HTTP_PROXY": resolvedProxyURL,
        "HTTPS_PROXY": resolvedProxyURL,
        "http_proxy": resolvedProxyURL,
        "https_proxy": resolvedProxyURL
    ]
}
