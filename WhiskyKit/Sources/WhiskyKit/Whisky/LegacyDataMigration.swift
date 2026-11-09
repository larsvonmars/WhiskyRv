//
//  LegacyDataMigration.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import os.log

/// Moves data that was created by upstream Whisky to the bundle identifier of this fork.
///
/// The Wine runtime and the logs are stored in folders derived from the bundle identifier and the preferences
/// are stored in the matching user defaults domain, so both have to be adopted when the identifier changes.
///
/// Bottles are intentionally kept in the container of upstream Whisky: macOS protects app containers and does
/// not allow one application to rename the container of another one, which would be required to move them.
public enum LegacyDataMigration {
    /// Runs the migration once. Later launches find the new folders already in place and do nothing.
    public static func migrateIfNeeded() {
        let newIdentifier = Bundle.whiskyBundleIdentifier
        let legacyIdentifier = Bundle.legacyWhiskyBundleIdentifier

        guard newIdentifier != legacyIdentifier else { return }

        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser.appending(path: "Library")
        let parents = [
            library.appending(path: "Application Support"),
            library.appending(path: "Logs")
        ]

        for parent in parents {
            let legacyFolder = parent.appending(path: legacyIdentifier)
            let newFolder = parent.appending(path: newIdentifier)

            guard fileManager.fileExists(atPath: legacyFolder.path(percentEncoded: false)),
                  !fileManager.fileExists(atPath: newFolder.path(percentEncoded: false)) else {
                continue
            }

            do {
                try fileManager.moveItem(at: legacyFolder, to: newFolder)
            } catch {
                Logger.wineKit.error("Failed to migrate \(legacyFolder.path(percentEncoded: false)): \(error)")
            }
        }

        migrateDefaults()
    }

    private static func migrateDefaults() {
        let defaults = UserDefaults.standard
        let newIdentifier = Bundle.whiskyBundleIdentifier

        guard defaults.persistentDomain(forName: newIdentifier) == nil,
              let legacyDomain = defaults.persistentDomain(forName: Bundle.legacyWhiskyBundleIdentifier) else {
            return
        }

        defaults.setPersistentDomain(legacyDomain, forName: newIdentifier)
    }
}
