//
//  Rosetta2.swift
//  Whisky
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

public class Rosetta2 {
    private static let rosetta2RuntimeBin = "/Library/Apple/usr/libexec/oah/libRosettaRuntime"

    public static let isRosettaInstalled: Bool = {
        if FileManager.default.fileExists(atPath: rosetta2RuntimeBin) {
            return true
        }

        // The runtime layout changed between macOS releases, so fall back to translating a tiny process.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        process.arguments = ["-x86_64", "/usr/bin/true"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }()

    public static func installRosetta() async throws -> Bool {
        let process = Process()
        let fileHandle = try Wine.makeFileHandle()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/softwareupdate")
        process.arguments = ["--install-rosetta", "--agree-to-license"]
        process.standardOutput = fileHandle
        process.standardError = fileHandle
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: process)

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { (process: Process) in
                do {
                    try fileHandle.close()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    Logger.wineKit.error("Error while closing file handle: \(error)")
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
