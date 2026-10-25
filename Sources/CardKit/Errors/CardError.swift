//
//  CardError.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

public enum CardError: Error, Equatable, LocalizedError {
    /// The card cannot be drawn; the message names the field.
    case invalid(String)
    /// The renderer gave no picture.
    case drawing

    public var errorDescription: String? {
        switch self {
        case .invalid(let problem): problem
        case .drawing: "the card could not be drawn"
        }
    }
}
