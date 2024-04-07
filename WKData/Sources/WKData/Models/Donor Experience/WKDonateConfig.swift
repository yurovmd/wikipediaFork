import Foundation

public struct WKDonateConfig: Codable {
    let version: Int
    public let currencyMinimumDonation: [String: Decimal]
    public let currencyMaximumDonation: [String: Decimal]
    public let currencyAmountPresets: [String: [Decimal]]
    public let currencyTransactionFees: [String: Decimal]
    public let countryCodeEmailOptInRequired: [String]
    
    public func transactionFee(for currencyCode: String) -> Decimal? {
        return currencyTransactionFees[currencyCode] ?? currencyTransactionFees["default"]
    }
}
