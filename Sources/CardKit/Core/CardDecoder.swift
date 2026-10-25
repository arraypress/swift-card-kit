//
//  CardDecoder.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Cards arrive as JSON with snake_case keys (`days_left`, `rest_label`), the
//  way `store` writes its fields. A mistake is reported by its path:
//  "blocks[1].rows[0] is missing of".
//

import Foundation

public enum CardDecoder {

    /// A card from JSON, or ``CardError/invalid(_:)`` naming where it went wrong.
    public static func card(from data: Data) throws -> Card {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Card.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            let at = path(context.codingPath)
            throw CardError.invalid((at.isEmpty ? "" : "\(at) ") + "is missing \(snake(key.stringValue))")
        } catch let DecodingError.typeMismatch(_, context), let DecodingError.valueNotFound(_, context) {
            throw CardError.invalid("\(path(context.codingPath)) has the wrong kind of value")
        } catch let DecodingError.dataCorrupted(context) {
            let at = path(context.codingPath)
            throw CardError.invalid(at.isEmpty ? "not JSON: \(context.debugDescription)" : "\(at): \(context.debugDescription)")
        }
    }

    /// "blocks[1].rows[0].days_left" from a decoding path.
    static func path(_ keys: [any CodingKey]) -> String {
        keys.reduce("") { text, key in
            if let index = key.intValue { return text + "[\(index)]" }
            return text.isEmpty ? snake(key.stringValue) : text + "." + snake(key.stringValue)
        }
    }

    /// "daysLeft" → "days_left", as the JSON spells it.
    static func snake(_ name: String) -> String {
        name.reduce(into: "") { out, c in
            if c.isUppercase { out += "_" + c.lowercased() } else { out.append(c) }
        }
    }
}
