import Darwin

@main
enum TestMain {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let selectedSuite: String?

        if arguments.isEmpty {
            selectedSuite = nil
        } else if arguments.count == 2, arguments[0] == "--suite" {
            selectedSuite = arguments[1]
        } else {
            print("Usage: CodexMeterTests [--suite <name>]")
            exit(2)
        }

        let selectedTests = if selectedSuite == "live" {
            TestRegistry.live
        } else if selectedSuite == "live-usage" {
            TestRegistry.liveUsage
        } else {
            TestRegistry.all.filter { test in
                selectedSuite == nil || test.suite == selectedSuite
            }
        }

        guard !selectedTests.isEmpty else {
            print("No tests found for suite '\(selectedSuite ?? "")'")
            exit(2)
        }

        var failedCount = 0

        for test in selectedTests {
            TestRecorder.reset()

            do {
                try await test.body()
            } catch {
                TestRecorder.record("threw unexpected error: \(error)")
            }

            if TestRecorder.failures.isEmpty {
                print("PASS [\(test.suite)] \(test.name)")
            } else {
                failedCount += 1
                print("FAIL [\(test.suite)] \(test.name)")
                TestRecorder.failures.forEach { print("  \($0)") }
            }
        }

        print("\(selectedTests.count) tests, \(failedCount) failures")
        exit(failedCount == 0 ? 0 : 1)
    }
}
