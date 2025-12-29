//
//  ProjectDrawingsView.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/29/25.
//

import SwiftUI

struct ProjectDrawingsView: View {
    @Binding var drawings: [Drawing]
    @Binding var activeDrawingId: UUID?

    var body: some View {
        List {
            if drawings.isEmpty {
                Text("No drawings uploaded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(drawings) { drawing in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(drawing.name)
                                .font(.headline)

                            if drawing.id == activeDrawingId {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        if drawing.id != activeDrawingId {
                            Button("Set Active") {
                                activeDrawingId = drawing.id
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle("Drawings")
    }
    private var activeDrawing: Drawing? {
        drawings.first { $0.id == activeDrawingId }
    }
}
