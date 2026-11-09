//
//  RuntimeDownloader.swift
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

import Combine
import Foundation

/// Describes which archives the Wine runtime should be installed from.
public enum RuntimeInstallPlan: Hashable, Sendable {
    /// Separate archives for Wine and DXVK, stored in `temporaryDirectory`.
    case components(wine: URL, dxvk: URL, temporaryDirectory: URL)
    /// A single archive that already contains the `Libraries` layout.
    case archive(URL)
}

public enum RuntimeDownloadError: LocalizedError {
    case httpStatus(String, Int)
    case incompleteDownload

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let component, let status):
            return "\(component) could not be downloaded (HTTP \(status))."
        case .incompleteDownload:
            return "The Wine runtime download is incomplete."
        }
    }
}

/// Downloads all components of the Wine runtime while publishing the progress to SwiftUI.
///
/// The published values are only mutated on the main queue, which keeps them in sync with the UI. The class
/// is marked as `@unchecked Sendable` because the state itself is only touched on the main queue.
public final class RuntimeDownloader: ObservableObject, @unchecked Sendable {
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var receivedBytes: Int64 = 0
    @Published public private(set) var expectedBytes: Int64 = RuntimeDownloader.totalExpectedBytes
    @Published public private(set) var componentName: String = ""
    @Published public private(set) var startedAt = Date()

    public init() {}

    private static var totalExpectedBytes: Int64 {
        WhiskyWineInstaller.components.reduce(0) { $0 + $1.expectedBytes }
    }

    /// Downloads every runtime component and returns a plan that can be handed to the installer.
    public func downloadAll() async throws -> RuntimeInstallPlan {
        let directory = try makeTemporaryDirectory()
        let destinationRoot = directory.appending(path: "Archives")
        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        await MainActor.run {
            self.startedAt = Date()
            self.receivedBytes = 0
            self.progress = 0
            self.expectedBytes = Self.totalExpectedBytes
        }

        var archives: [String: URL] = [:]
        var previousBytes: Int64 = 0

        do {
            for component in WhiskyWineInstaller.components {
                await MainActor.run { self.componentName = component.name }

                let archive = try await download(component, into: destinationRoot, previousBytes: previousBytes)
                let size = Self.size(of: archive)
                archives[component.name] = archive
                previousBytes += size
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        guard let wineArchive = archives[WhiskyWineInstaller.wineComponent.name],
              let dxvkArchive = archives[WhiskyWineInstaller.dxvkComponent.name] else {
            throw RuntimeDownloadError.incompleteDownload
        }

        await MainActor.run {
            self.receivedBytes = self.expectedBytes
            self.progress = 1
        }

        return .components(wine: wineArchive, dxvk: dxvkArchive, temporaryDirectory: directory)
    }

    private func download(
        _ component: RuntimeComponent, into directory: URL, previousBytes: Int64
    ) async throws -> URL {
        let delegate = DownloadProgressDelegate { [weak self] writtenBytes in
            self?.report(receivedBytes: previousBytes + writtenBytes)
        }
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (temporaryURL, response) = try await session.download(from: component.url)

        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            throw RuntimeDownloadError.httpStatus(component.name, (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let destination = directory.appending(path: component.fileName)

        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func report(receivedBytes: Int64) {
        DispatchQueue.main.async {
            self.receivedBytes = receivedBytes
            self.progress = self.expectedBytes > 0
                ? min(Double(receivedBytes) / Double(self.expectedBytes), 1)
                : 0
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "WhiskyRuntime-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func size(of url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)
        ) else {
            return 0
        }

        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64) -> Void

    init(onProgress: @escaping @Sendable (Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The download is handed over to the caller by `URLSession.download(from:)`.
    }
}
