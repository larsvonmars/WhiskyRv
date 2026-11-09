//
//  WhiskyWineInstallView.swift
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
import WhiskyKit

struct WhiskyWineInstallView: View {
    let plan: RuntimeInstallPlan
    @Binding var path: [SetupStage]
    @Binding var showSetup: Bool
    @State private var isInstalling: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            VStack {
                Text("setup.whiskywine.install")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.whiskywine.install.subtitle")
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
                } else if isInstalling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 80)
                } else {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            Spacer()
            HStack {
                if errorMessage != nil {
                    Button("button.back") {
                        path.removeLast()
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("setup.retry") {
                        Task {
                            await install()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 400, height: 200)
        .task {
            await install()
        }
    }

    func install() async {
        isInstalling = true
        errorMessage = nil

        do {
            try await Task.detached(priority: .userInitiated) {
                switch plan {
                case .components(let wine, let dxvk, let temporaryDirectory):
                    try WhiskyWineInstaller.install(wineArchive: wine, dxvkArchive: dxvk)
                    try? FileManager.default.removeItem(at: temporaryDirectory)
                case .archive(let archive):
                    try WhiskyWineInstaller.install(from: archive)
                }
            }.value

            isInstalling = false
            try? await Task.sleep(for: .seconds(2))
            showSetup = false
        } catch {
            isInstalling = false
            errorMessage = error.localizedDescription
        }
    }
}
