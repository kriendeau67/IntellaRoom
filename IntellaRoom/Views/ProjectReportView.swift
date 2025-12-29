//
//  ProjectReportView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/29/25.
//

import SwiftUI

struct ProjectReportView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedScan: Scan?
    @State private var selectedRoom: Room?

    var body: some View {
        List {
            if appState.rooms.isEmpty {
                ContentUnavailableView(
                    "No Rooms Yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Rooms and scans will appear here once captured.")
                )
            } else {
                ForEach(appState.rooms) { room in
                    Section {
                        let scans = appState.scans(in: room)

                        if scans.isEmpty {
                            Text("No scans in this room")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(scans) { scan in
                                Button {
                                    selectedRoom = room
                                    selectedScan = scan
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Scan")
                                                .font(.headline)

                                            Text("\(scan.imageFileNames.count) images")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            let scans = appState.scans(in: room)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.headline)

                                Text("\(scans.count) scan\(scans.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedScan) { scan in
            if let room = selectedRoom {
                ScanDetailView(scan: scan, room: room)
            }
        }
    }
}
