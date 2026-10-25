//
//  Status.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where something stands. Each has its own colour AND icon, so it never rests on colour alone.
public enum Status: String, Codable, Sendable, CaseIterable {
    /// On track, under, done.
    case good
    /// Past a limit.
    case over
    /// Needs doing now: due today, an allergy, a failure.
    case critical
    /// Just information.
    case neutral
}

/// Light or dark: the same layout with the colours swapped.
public enum CardTheme: String, Codable, Sendable, CaseIterable {
    case light, dark
}
