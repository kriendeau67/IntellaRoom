//
//  Project.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import Foundation

struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var foreman: String
    var createdAt: Date
}
