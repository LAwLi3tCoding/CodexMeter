import CodexMeterCore

let codexLiveSmoke: [HarnessTest] = [
    HarnessTest(
        suite: "live",
        name: "Installed Codex CLI returns a non-empty quota snapshot",
        body: testLiveCodexSnapshot
    )
]

private func testLiveCodexSnapshot() async throws {
    let client = try CodexAppServerClient()

    do {
        let snapshot = try await CodexProvider(client: client).fetchSnapshot()
        await client.shutdown()
        expectEqual(snapshot.provider, .codex)
        if snapshot.quotas.isEmpty {
            TestRecorder.record("expected at least one quota window")
        }
    } catch {
        await client.shutdown()
        throw error
    }
}
