//
//  WhiskyWineDownloadView.swift
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

import SwiftUI
import UniformTypeIdentifiers
import WhiskyKit

struct WhiskyWineDownloadView: View {
    @StateObject private var downloader = RuntimeDownloader()
    @State private var errorMessage: String?
    @State private var isDownloading: Bool = false
    @Binding var path: [SetupStage]

    var body: some View {
        VStack {
            VStack {
                Text("setup.whiskywine.download")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.whiskywine.download.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .foregroundStyle(.red)
                            .frame(width: 60, height: 60)
                        Text("setup.whiskywine.error")
                            .font(.subheadline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack {
                        ProgressView(value: downloader.progress, total: 1)
                        HStack(spacing: 4) {
                            Text(downloader.componentName)
                            Text(String(format: String(localized: "setup.whiskywine.progress"),
                                        formatBytes(bytes: downloader.receivedBytes),
                                        formatBytes(bytes: downloader.expectedBytes)))
                            if let remainingTime = remainingTime() {
                                Text(String(format: String(localized: "setup.whiskywine.eta"), remainingTime))
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                    .padding(.horizontal)
                }
                Spacer()
            }
            Spacer()
            HStack {
                if errorMessage != nil {
                    Button("setup.quit") {
                        exit(0)
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("setup.whiskywine.import") {
                        importArchive()
                    }
                    Button("setup.retry") {
                        Task {
                            await startDownload()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 400, height: 200)
        .task {
            await startDownload()
        }
    }

    func startDownload() async {
        guard !isDownloading else { return }

        isDownloading = true
        errorMessage = nil

        do {
            let plan = try await downloader.downloadAll()
            isDownloading = false
            path.append(.whiskyWineInstall(plan))
        } catch {
            isDownloading = false
            errorMessage = error.localizedDescription
        }
    }

    func importArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.archive, .gzip, UTType(filenameExtension: "xz") ?? .archive]

        if panel.runModal() == .OK, let url = panel.urls.first {
            path.append(.whiskyWineInstall(.archive(url)))
        }
    }

    func formatBytes(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }

    func remainingTime() -> String? {
        let elapsedTime = Date().timeIntervalSince(downloader.startedAt)
        let receivedBytes = downloader.receivedBytes
        let remainingBytes = downloader.expectedBytes - receivedBytes

        guard Int(elapsedTime.rounded()) > 5, receivedBytes > 0, remainingBytes > 0 else {
            return nil
        }

        let remainingTimeInSeconds = Double(remainingBytes) / (Double(receivedBytes) / elapsedTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(remainingTimeInSeconds))
    }
}
