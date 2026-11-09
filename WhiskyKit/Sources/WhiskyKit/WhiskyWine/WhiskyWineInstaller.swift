//
//  WhiskyWineInstaller.swift
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
import SemanticVersion

/// A download that is required to assemble the Wine runtime.
public struct RuntimeComponent: Sendable, Hashable, Identifiable {
    public var id: String { name }

    /// Human readable name of the component, e.g. `Wine` or `DXVK`.
    public let name: String
    /// Remote location of the archive.
    public let url: URL
    /// Expected download size in bytes, used to render a meaningful progress indicator.
    public let expectedBytes: Int64

    /// File name the component is stored as.
    public var fileName: String { url.lastPathComponent }

    public init(name: String, url: URL, expectedBytes: Int64) {
        self.name = name
        self.url = url
        self.expectedBytes = expectedBytes
    }
}

public enum RuntimeInstallError: LocalizedError {
    case wineNotFound
    case dxvkNotFound

    public var errorDescription: String? {
        switch self {
        case .wineNotFound:
            return "The archive does not contain a Wine installation."
        case .dxvkNotFound:
            return "The archive does not contain DXVK libraries."
        }
    }
}

public class WhiskyWineInstaller {
    /// The Wine version that Whisky installs and supports.
    public static let supportedRuntimeVersion = SemanticVersion(11, 21, 0)

    /// Prebuilt Wine binaries. Wine is distributed as an `x86_64` build which is translated by Rosetta 2.
    public static let wineComponent = RuntimeComponent(
        name: "Wine",
        url: runtimeURL(wineDownloadBase, wineFileName),
        expectedBytes: 228_148_688)

    /// DXVK libraries used for Direct3D 9/10/11 on top of MoltenVK.
    public static let dxvkComponent = RuntimeComponent(
        name: "DXVK",
        url: runtimeURL(dxvkDownloadBase, dxvkFileName),
        expectedBytes: 2_793_443)

    /// All components that make up the runtime, in download order.
    public static let components = [wineComponent, dxvkComponent]

    /// The Whisky application folder
    public static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    /// The folder of all the library files
    public static let libraryFolder = applicationFolder.appending(path: "Libraries")

    /// URL to the installed `wine` `bin` directory
    public static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    /// URL to the `wine` executable.
    ///
    /// Older runtimes shipped a separate `wine64` binary. Current Wine builds are WoW64 capable and only
    /// provide a single `wine` binary, so prefer the legacy name when it is available.
    public static var wineExecutableURL: URL {
        let wine64 = binFolder.appending(path: "wine64")

        if FileManager.default.fileExists(atPath: wine64.path(percentEncoded: false)) {
            return wine64
        }

        return binFolder.appending(path: "wine")
    }

    /// File name of the `wine` executable, e.g. `wine64` or `wine`.
    public static var wineExecutableName: String {
        wineExecutableURL.lastPathComponent
    }

    public static func isWhiskyWineInstalled() -> Bool {
        guard whiskyWineVersion() != nil else { return false }
        return FileManager.default.fileExists(atPath: wineExecutableURL.path(percentEncoded: false))
    }

    /// Installs a runtime from previously downloaded component archives.
    public static func install(wineArchive: URL, dxvkArchive: URL?) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)

        let staging = applicationFolder.appending(path: ".staging-\(UUID().uuidString)")
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: staging)
            try? fileManager.removeItem(at: wineArchive)

            if let dxvkArchive {
                try? fileManager.removeItem(at: dxvkArchive)
            }
        }

        let wineExtract = staging.appending(path: "wine")
        try fileManager.createDirectory(at: wineExtract, withIntermediateDirectories: true)
        try Tar.untar(tarBall: wineArchive, toURL: wineExtract)

        // Validate both archives before replacing the installed runtime.
        let wineRoot = try findWineRoot(in: wineExtract)
        var dxvkRoot: URL?

        if let dxvkArchive {
            let dxvkExtract = staging.appending(path: "dxvk")
            try fileManager.createDirectory(at: dxvkExtract, withIntermediateDirectories: true)
            try Tar.untar(tarBall: dxvkArchive, toURL: dxvkExtract)
            dxvkRoot = try findDXVKRoot(in: dxvkExtract)
        }

        let wineDestination = libraryFolder.appending(path: "Wine")

        if fileManager.fileExists(atPath: wineDestination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: wineDestination)
        }

        try fileManager.moveItem(at: wineRoot, to: wineDestination)

        if let dxvkRoot {
            try installDXVK(from: dxvkRoot)
        }

        try writeVersionPlist()
    }

    /// Installs a complete `WhiskyWine` compatible archive, which already contains the expected
    /// `Libraries` layout.
    public static func install(from archive: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: applicationFolder.path(percentEncoded: false)) {
            try fileManager.removeItem(at: applicationFolder)
        }

        try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
        try Tar.untar(tarBall: archive, toURL: applicationFolder)
        try fileManager.removeItem(at: archive)
    }

    public static func uninstall() {
        do {
            try FileManager.default.removeItem(at: libraryFolder)
        } catch {
            print("Failed to uninstall WhiskyWine: \(error)")
        }
    }

    /// Returns the version that should be installed if the local runtime is outdated, `nil` otherwise.
    public static func outdatedRuntimeVersion() -> SemanticVersion? {
        guard let localVersion = whiskyWineVersion(), localVersion < supportedRuntimeVersion else {
            return nil
        }

        return supportedRuntimeVersion
    }

    public static func whiskyWineVersion() -> SemanticVersion? {
        do {
            let versionPlist = libraryFolder
                .appending(path: "WhiskyWineVersion")
                .appendingPathExtension("plist")

            let decoder = PropertyListDecoder()
            let data = try Data(contentsOf: versionPlist)
            let info = try decoder.decode(WhiskyWineVersion.self, from: data)
            return info.version
        } catch {
            print(error)
            return nil
        }
    }
}

extension WhiskyWineInstaller {
    private static let wineDownloadBase = "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.21"
    private static let wineFileName = "wine-staging-11.21-osx64.tar.xz"

    private static let dxvkDownloadBase =
        "https://github.com/Gcenx/DXVK-macOS/releases/download/v1.10.3-20230507-repack"
    private static let dxvkFileName = "dxvk-macOS-async-v1.10.3-20230507-repack.tar.gz"

    private static func runtimeURL(_ base: String, _ fileName: String) -> URL {
        guard let url = URL(string: "\(base)/\(fileName)") else {
            preconditionFailure("Malformed runtime URL: \(base)/\(fileName)")
        }

        return url
    }

    private static func writeVersionPlist() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(WhiskyWineVersion(version: supportedRuntimeVersion))
        let versionPlist = libraryFolder
            .appending(path: "WhiskyWineVersion")
            .appendingPathExtension("plist")
        try data.write(to: versionPlist)
    }

    private static func installDXVK(from dxvkRoot: URL) throws {
        let fileManager = FileManager.default
        let dxvkDestination = libraryFolder.appending(path: "DXVK")

        if fileManager.fileExists(atPath: dxvkDestination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: dxvkDestination)
        }

        try fileManager.createDirectory(at: dxvkDestination, withIntermediateDirectories: true)

        for architecture in ["x64", "x32"] {
            let source = dxvkRoot.appending(path: architecture)

            if fileManager.fileExists(atPath: source.path(percentEncoded: false)) {
                try fileManager.copyItem(at: source, to: dxvkDestination.appending(path: architecture))
            }
        }

        let configuration = dxvkRoot.appending(path: "dxvk.conf")

        if fileManager.fileExists(atPath: configuration.path(percentEncoded: false)) {
            try fileManager.copyItem(at: configuration, to: dxvkDestination.appending(path: "dxvk.conf"))
        }
    }

    private static func findWineRoot(in directory: URL) throws -> URL {
        if isWineRoot(directory) {
            return directory
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeInstallError.wineNotFound
        }

        for case let url as URL in enumerator where isWineRoot(url) {
            return url
        }

        throw RuntimeInstallError.wineNotFound
    }

    private static func isWineRoot(_ url: URL) -> Bool {
        let bin = url.appending(path: "bin")
        let fileManager = FileManager.default
        let hasWine = fileManager.fileExists(atPath: bin.appending(path: "wine").path(percentEncoded: false))
        let hasWine64 = fileManager.fileExists(atPath: bin.appending(path: "wine64").path(percentEncoded: false))

        return (hasWine || hasWine64) &&
            fileManager.fileExists(atPath: bin.appending(path: "wineserver").path(percentEncoded: false))
    }

    private static func findDXVKRoot(in directory: URL) throws -> URL {
        if isDXVKRoot(directory) {
            return directory
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeInstallError.dxvkNotFound
        }

        for case let url as URL in enumerator where isDXVKRoot(url) {
            return url
        }

        throw RuntimeInstallError.dxvkNotFound
    }

    private static func isDXVKRoot(_ url: URL) -> Bool {
        let fileManager = FileManager.default

        return fileManager.fileExists(atPath: url.appending(path: "x64").path(percentEncoded: false)) &&
            fileManager.fileExists(atPath: url.appending(path: "x32").path(percentEncoded: false))
    }
}

struct WhiskyWineVersion: Codable {
    var version: SemanticVersion = SemanticVersion(1, 0, 0)
}
