import Foundation
import CodexMeterCore

let codexProtocolDecoding: [HarnessTest] = [
    HarnessTest(
        suite: "protocol",
        name: "Rate limits decode optional multi-bucket windows",
        body: testRateLimitDecoding
    ),
    HarnessTest(
        suite: "protocol",
        name: "Account and effective model decode narrowly",
        body: testAccountAndConfigDecoding
    )
]

private func testRateLimitDecoding() throws {
    let data = Data(
        #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1730947200},
            "secondary": null,
            "planType": "pro"
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1730947200},
              "secondary": {"usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 1731552000}
            }
          }
        }
        """#.utf8
    )

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: data)

    expectEqual(response.rateLimits.primary?.usedPercent, 25)
    expectNil(response.rateLimits.secondary)
    expectEqual(response.rateLimitsByLimitId?["codex"]?.secondary?.windowDurationMins, 10_080)
    expectEqual(response.rateLimits.planType, "pro")
}

private func testAccountAndConfigDecoding() throws {
    let accountData = Data(
        #"""
        {
          "account": {"type": "chatgpt", "email": "developer@example.com", "planType": "plus"},
          "requiresOpenaiAuth": true
        }
        """#.utf8
    )
    let configData = Data(
        #"""
        {
          "config": {"model": "gpt-5.5", "mcpServers": {"ignored": {"env": {"SECRET": "not-decoded"}}}},
          "origins": {}
        }
        """#.utf8
    )

    let account = try JSONDecoder().decode(CodexAccountResponse.self, from: accountData)
    let config = try JSONDecoder().decode(CodexConfigResponse.self, from: configData)

    expectEqual(account.account?.type, "chatgpt")
    expectEqual(account.account?.email, "developer@example.com")
    expectEqual(account.account?.planType, "plus")
    expectEqual(config.config.model, "gpt-5.5")
}
