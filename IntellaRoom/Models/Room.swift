//
//  Room.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import Foundation

struct Room: Identifiable, Codable, Hashable {
    let id: String
    let projectId: String
    let drawingId: UUID
   // let pdfId: String

    var name: String
    var pinX: Double     // normalized 0–1
    var pinY: Double     // normalized 0–1

    let createdAt: Date
}
