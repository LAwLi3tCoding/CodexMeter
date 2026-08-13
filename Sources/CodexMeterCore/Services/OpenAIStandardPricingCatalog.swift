import Foundation

public struct OpenAIStandardPricingCatalog: Sendable {
    private struct Rates: Sendable {
        let input: Double
        let cachedInput: Double
        let output: Double
    }

    public static let pricingVersion = "2026-08-08"
    public static let estimationNote =
        "API-equivalent estimate using standard rates (Aug 8, 2026), model weights observed from local thread token metadata for each period, and a 14% input, 85% cached-input, 1% output Codex workload mix. Thread attribution is approximate; subscription charges may differ."

    public init() {}

    public func estimatedCostUSD(tokens: Int64, model: String) -> Double? {
        guard let rates = rates(for: model) else { return nil }
        let blendedRate = (rates.input * 0.14)
            + (rates.cachedInput * 0.85)
            + (rates.output * 0.01)
        return (Double(max(0, tokens)) / 1_000_000) * blendedRate
    }

    private func rates(for model: String) -> Rates? {
        switch normalizedModel(model) {
        case "gpt-5.6", "gpt-5.6-sol", "gpt-5.5":
            return Rates(input: 5, cachedInput: 0.5, output: 30)
        case "gpt-5.6-terra":
            return Rates(input: 2, cachedInput: 0.2, output: 12)
        case "gpt-5.6-luna":
            return Rates(input: 0.2, cachedInput: 0.02, output: 1.2)
        case "gpt-5.4":
            return Rates(input: 2.5, cachedInput: 0.25, output: 15)
        case "gpt-5.4-mini":
            return Rates(input: 0.75, cachedInput: 0.075, output: 4.5)
        case "gpt-5.4-nano":
            return Rates(input: 0.2, cachedInput: 0.02, output: 1.25)
        case "gpt-5.3-codex":
            return Rates(input: 1.75, cachedInput: 0.175, output: 14)
        case "gpt-5.2":
            return Rates(input: 1.75, cachedInput: 0.175, output: 14)
        case "gpt-5.1", "gpt-5":
            return Rates(input: 1.25, cachedInput: 0.125, output: 10)
        case "gpt-5-mini":
            return Rates(input: 0.25, cachedInput: 0.025, output: 2)
        case "gpt-5-nano":
            return Rates(input: 0.05, cachedInput: 0.005, output: 0.4)
        default:
            return nil
        }
    }

    private func normalizedModel(_ model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
