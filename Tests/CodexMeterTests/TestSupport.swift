struct HarnessTest {
    let suite: String
    let name: String
    let body: () async throws -> Void
}

enum TestRecorder {
    private(set) static var failures: [String] = []

    static func reset() {
        failures.removeAll(keepingCapacity: true)
    }

    static func record(_ message: String) {
        failures.append(message)
    }
}

func expectEqual<Value: Equatable>(
    _ actual: Value,
    _ expected: Value,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    guard actual != expected else { return }

    TestRecorder.record(
        "\(file):\(line): expected \(String(reflecting: expected)), "
            + "got \(String(reflecting: actual))"
    )
}

func expectNil<Value>(
    _ actual: Value?,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    guard let actual else { return }

    TestRecorder.record(
        "\(file):\(line): expected nil, got \(String(reflecting: actual))"
    )
}
