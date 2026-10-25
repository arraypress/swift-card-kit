//
//  CardFiles.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Where a card goes when nobody says: a folder only this user can read
//  (~/Library/Caches/arraypress/cards, mode 0700), each card a new name, and
//  anything older than a day removed whenever a card is written. Cards show
//  meals, money and health; they don't belong in /tmp, and they shouldn't
//  pile up once sent.
//

import Foundation

public enum CardFiles {

    /// How long a card stays: long enough to be sent, not long enough to become an archive.
    public static let keep: TimeInterval = 24 * 3600

    /// The private folder, made 0700 if missing.
    public static func folder(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let folder = home.appendingPathComponent("Library/Caches/arraypress/cards", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        return folder
    }

    /// A new file in the private folder for one card, after clearing out cards older than ``keep``.
    public static func newCard(home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = Date()) throws -> URL {
        let folder = try folder(home: home)
        prune(folder, now: now)
        return folder.appendingPathComponent("card-\(UUID().uuidString.prefix(8).lowercased()).png")
    }

    /// Removes cards older than ``keep``; returns how many.
    @discardableResult
    public static func prune(_ folder: URL, now: Date = Date()) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var removed = 0
        for file in files where file.lastPathComponent.hasPrefix("card-") && file.pathExtension == "png" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if now.timeIntervalSince(modified) > keep, (try? FileManager.default.removeItem(at: file)) != nil { removed += 1 }
        }
        return removed
    }
}
