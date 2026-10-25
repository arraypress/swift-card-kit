//
//  Words.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Every phrase the kit writes itself, by id, with {placeholders}. English by
//  default; a card's `wording` replaces any of them — another language, or
//  the owner's own words. Numbers inside them are already written for the
//  card's locale.
//

import Foundation

public struct Words: Sendable, Equatable {

    /// Every phrase id, its English, and so its placeholders.
    public static let english: [String: String] = [
        "left_of": "left of {total}",
        "over_of": "over {total}",
        "a_day": "About {amount} a day for the {days} days left",
        "a_day_one": "About {amount} a day for the 1 day left",
        "over_the_limit": "{amount} over the limit",
        "all_within": "Every part within its limit",
        "some_over": "{over} of {count} over their limit",
        "row_over": "{amount} over",
        "in_all": "in all",
        "less_than": "{amount} less than {label}",
        "more_than": "{amount} more than {label}",
        "same_as": "Same as {label}",
        "change_new": "new",
        "change_same": "same",
        "under_target": "{amount} under the target",
        "over_target": "{amount} over the target",
        "on_target": "On target",
        "goal_reached": "Goal reached",
        "to_goal": "{amount} to the goal",
        "vs_average": "{change} against the average of {amount}",
        "about_average": "About your average",
        "legend_goal": "Goal {amount}",
        "legend_band": "Target band",
        "legend_average": "Average {amount}",
        "legend_pace": "Target pace",
        "legend_smoothed": "{name}, {n}-point average",
        "under_by_now": "{amount} under {name} by now",
        "over_by_now": "{amount} over {name} by now",
        "level_by_now": "Level with {name} by now",
        "up_over_period": "Up {amount} over the period",
        "down_over_period": "Down {amount} over the period",
        "level_over_period": "Level over the period",
        "so_far": "so far",
        "projection": "At this pace about {amount} by the end",
        "projection_under": " — {amount} under {name}",
        "projection_over": " — {amount} over {name}",
        "projection_on": ", right on {name}",
        "the_target": "the target",
        "free": "Free",
        "less": "Less",
        "more": "More",
        "before": "Before",
        "after": "After",
        "map_unavailable": "Map not available: no connection when this was drawn",
        "earned": "Earned {date}",
        "of": "of {total}",
    ]

    public var overrides: [String: String]

    public init(_ overrides: [String: String]? = nil) { self.overrides = overrides ?? [:] }

    /// The phrase, its placeholders filled. An unknown id comes back as itself, so a typo shows rather than hides.
    public func callAsFunction(_ id: String, _ values: [String: String] = [:]) -> String {
        var phrase = overrides[id] ?? Words.english[id] ?? id
        for (key, value) in values { phrase = phrase.replacingOccurrences(of: "{\(key)}", with: value) }
        return phrase
    }

    /// The placeholders a phrase uses: "{amount} over the limit" → ["amount"].
    public static func placeholders(_ phrase: String) -> Set<String> {
        var found = Set<String>(), rest = Substring(phrase)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            found.insert(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return found
    }
}
