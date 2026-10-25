//
//  Amount.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A number on a card: money (an exact decimal and an ISO 4217 currency, the
//  shape `store` writes — {"amount": "4.20", "currency": "GBP"}) or a plain
//  number (kcal, kg, steps) whose unit the card names.
//

import Foundation

public struct Amount: Codable, Equatable, Sendable {

    /// The exact value. Money is never a Double.
    public var value: Decimal
    /// ISO 4217 code for money; nil for a plain number.
    public var currency: String?

    public init(_ value: Decimal, currency: String? = nil) {
        self.value = value
        self.currency = currency?.uppercased()
    }

    private enum Keys: String, CodingKey { case amount, currency }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let number = try? single.decode(Decimal.self) {
            self.init(number)
            return
        }
        let keyed = try decoder.container(keyedBy: Keys.self)
        let currency = try keyed.decode(String.self, forKey: .currency)
        if let text = try? keyed.decode(String.self, forKey: .amount) {
            guard let exact = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(forKey: .amount, in: keyed, debugDescription: "'\(text)' is not a number")
            }
            self.init(exact, currency: currency)
        } else {
            self.init(try keyed.decode(Decimal.self, forKey: .amount), currency: currency)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        if let currency {
            var keyed = encoder.container(keyedBy: Keys.self)
            try keyed.encode(CardMath.plain(value), forKey: .amount)
            try keyed.encode(currency, forKey: .currency)
        } else {
            var single = encoder.singleValueContainer()
            try single.encode(value)
        }
    }
}
