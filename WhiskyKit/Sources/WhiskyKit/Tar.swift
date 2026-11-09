//
//  Tar.swift
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

public class Tar {
    static let tarBinary: URL = URL(fileURLWithPath: "/usr/bin/tar")

    public static func tar(folder: URL, toURL: URL) throws {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = tarBinary
        process.arguments = ["-zcf", "\(toURL.path)", "\(folder.path)"]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        if let output = try pipe.fileHandleForReading.readToEnd() {
            let outputString = String(data: output, encoding: .utf8) ?? String()
            process.waitUntilExit()
            let status = process.terminationStatus
            if status != 0 {
                throw outputString
            }
        }
    }

    /// Extracts `tarBall` into `toURL`.
    ///
    /// Compression is detected automatically by `tar` itself, so `gzip`, `bzip2`, `xz` and `zstd` archives
    /// are all supported.
    public static func untar(tarBall: URL, toURL: URL) throws {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = tarBinary
        process.arguments = ["-xf", "\(tarBall.path)", "-C", "\(toURL.path)"]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let output = try pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let outputString = output.flatMap { String(data: $0, encoding: .utf8) } ?? String()
            throw TarError.extractionFailed(tarBall.lastPathComponent, outputString)
        }
    }
}

public enum TarError: LocalizedError {
    case extractionFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case .extractionFailed(let archive, let output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "Failed to extract \(archive)."
                : "Failed to extract \(archive): \(detail)"
        }
    }
}

extension String: @retroactive Error {}
