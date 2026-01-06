//
//  Drawing.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/29/25.
//
import Foundation

struct Drawing: Identifiable, Codable, Hashable {
    let id: UUID
    let projectId: UUID
    var name: String
    let localURL: URL
    let createdAt: Date
}
