//
//  ScanReportSelection.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 1/20/26.
//

import Foundation

struct ScanReportSelection: Identifiable {
    let id: String // This will be the scan ID
    let scan: Scan
    let room: Room
}
