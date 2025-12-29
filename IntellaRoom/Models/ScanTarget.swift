//
//  ScanTarget.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//
import SwiftUI

// 1. Define a "Package" that holds our scan data
struct ScanTarget: Identifiable {
    let id = UUID()
    let point: CGPoint
    let roomName: String
}
