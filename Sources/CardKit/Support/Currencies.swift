//
//  Currencies.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  How many decimal places a currency's smallest unit has (ISO 4217's minor
//  unit). Two unless listed: the yen has none, the Bahraini dinar three.
//

import Foundation

enum Currencies {

    static let noDecimals: Set<String> = ["BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX",
                                          "UYI", "VND", "VUV", "XAF", "XOF", "XPF"]
    static let threeDecimals: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]

    /// Decimal places of the currency's smallest unit.
    static func exponent(_ code: String) -> Int {
        let code = code.uppercased()
        if noDecimals.contains(code) { return 0 }
        if threeDecimals.contains(code) { return 3 }
        return 2
    }

    /// A plausible ISO 4217 code: three letters.
    static func isCode(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }
}
